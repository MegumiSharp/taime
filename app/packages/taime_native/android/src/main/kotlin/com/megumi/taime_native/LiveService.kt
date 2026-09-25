package com.megumi.taime_native

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * The focus timer as a media-style notification: big kitten artwork, title,
 * a progress bar the system advances on its own (position + speed 1.0), and
 * pause / resume / stop. Runs as a foreground service so the session and its
 * buttons survive the app being swiped away.
 *
 * Never touches audio focus: Taime plays no sound here, so music keeps playing
 * and headphone buttons stay with the app that last played audio.
 */
class LiveService : Service() {

    companion object {
        private const val CHANNEL = "taime_live"
        private const val NOTIF_ID = 7

        fun update(ctx: Context, args: Map<String, Any?>) {
            val i = Intent(ctx, LiveService::class.java).setAction("update")
            i.putExtra("title", args["title"] as String? ?: "Taime")
            i.putExtra("subtitle", args["subtitle"] as String? ?: "")
            i.putExtra("paused", args["paused"] as Boolean? ?: false)
            i.putExtra("color", (args["color"] as Number?)?.toInt() ?: 0xFF93C4A0.toInt())
            i.putExtra("positionMs", (args["positionMs"] as Number?)?.toLong() ?: 0L)
            i.putExtra("durationMs", (args["durationMs"] as Number?)?.toLong() ?: 3_600_000L)
            i.putExtra("sinceMs", (args["sinceMs"] as Number?)?.toLong() ?: System.currentTimeMillis())
            i.putExtra("artPath", args["artPath"] as String?)
            try {
                ContextCompat.startForegroundService(ctx, i)
            } catch (_: Exception) {
                // Starting from the background can be refused; the next update
                // from the app will bring it back.
            }
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, LiveService::class.java))
        }
    }

    private var session: MediaSessionCompat? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (val action = intent?.action) {
            "update" -> show(intent)
            "pause", "resume", "stop" -> TaimeNativePlugin.dispatchAction(this, action)
            else -> if (session == null) stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) != null) return
        val ch = NotificationChannel(CHANNEL, "Focus in corso", NotificationManager.IMPORTANCE_LOW)
        ch.description = "Il gattino e il tempo della sessione, anche sul blocco schermo"
        ch.setShowBadge(false)
        ch.setSound(null, null)
        ch.enableVibration(false)
        ch.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        nm.createNotificationChannel(ch)
    }

    private fun servicePending(action: String, code: Int): PendingIntent =
        PendingIntent.getService(
            this, code,
            Intent(this, LiveService::class.java).setAction(action),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

    private fun openAppPending(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        launch.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        return PendingIntent.getActivity(
            this, 10, launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun session(): MediaSessionCompat {
        session?.let { return it }
        val s = MediaSessionCompat(this, "taime_focus")
        s.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() = TaimeNativePlugin.dispatchAction(this@LiveService, "resume")
            override fun onPause() = TaimeNativePlugin.dispatchAction(this@LiveService, "pause")
            override fun onStop() = TaimeNativePlugin.dispatchAction(this@LiveService, "stop")
            override fun onCustomAction(action: String?, extras: android.os.Bundle?) {
                if (action == "stop") TaimeNativePlugin.dispatchAction(this@LiveService, "stop")
            }
        })
        s.isActive = true
        session = s
        return s
    }

    private fun show(i: Intent) {
        ensureChannel()
        val title = i.getStringExtra("title") ?: "Taime"
        val subtitle = i.getStringExtra("subtitle") ?: ""
        val paused = i.getBooleanExtra("paused", false)
        val color = i.getIntExtra("color", 0xFF93C4A0.toInt())
        val position = i.getLongExtra("positionMs", 0L)
        val duration = i.getLongExtra("durationMs", 3_600_000L)
        val since = i.getLongExtra("sinceMs", System.currentTimeMillis())
        val art: Bitmap? = i.getStringExtra("artPath")?.let {
            try {
                BitmapFactory.decodeFile(it)
            } catch (_: Exception) {
                null
            }
        }

        val s = session()
        s.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, subtitle)
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, subtitle)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
                .apply { if (art != null) putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, art) }
                .build()
        )
        s.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setState(
                    if (paused) PlaybackStateCompat.STATE_PAUSED else PlaybackStateCompat.STATE_PLAYING,
                    position.coerceIn(0, duration),
                    if (paused) 0f else 1f
                )
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or PlaybackStateCompat.ACTION_STOP
                )
                .addCustomAction(
                    PlaybackStateCompat.CustomAction.Builder("stop", "Termina", R.drawable.ic_taime_stop).build()
                )
                .build()
        )

        val toggle = if (paused) {
            NotificationCompat.Action(R.drawable.ic_taime_play, "Riprendi", servicePending("resume", 1))
        } else {
            NotificationCompat.Action(R.drawable.ic_taime_pause, "Pausa", servicePending("pause", 2))
        }
        val stop = NotificationCompat.Action(R.drawable.ic_taime_stop, "Termina", servicePending("stop", 3))

        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_taime_notif)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setLargeIcon(art)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(true)
            .setWhen(since)
            .setUsesChronometer(!paused)
            .setColor(color)
            .setColorized(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setContentIntent(openAppPending())
            .addAction(toggle)
            .addAction(stop)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(s.sessionToken)
                    .setShowActionsInCompactView(0, 1)
            )
            .build()

        val type = if (Build.VERSION.SDK_INT >= 34) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else 0
        ServiceCompat.startForeground(this, NOTIF_ID, n, type)
    }

    override fun onDestroy() {
        session?.let {
            it.isActive = false
            it.release()
        }
        session = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
