package com.megumi.taime_native

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * The focus timer notification: the kitten, the activity, a live chronometer
 * and a growth bar, with Pausa/Riprendi and Termina. It runs as a foreground
 * service and refreshes itself every 30 s, so the kitten grows (and the
 * auto-pause/pomodoro deadlines fire) even with the app closed.
 */
class LiveService : Service() {

    companion object {
        private const val CHANNEL = "taime_focus"
        private const val NOTIF_ID = 7
        const val PREFS = "taime_native"

        fun update(ctx: Context, args: Map<String, Any?>) {
            val i = Intent(ctx, LiveService::class.java).setAction("update")
            fun long(k: String) = (args[k] as Number?)?.toLong() ?: 0L
            i.putExtra("title", args["title"] as String? ?: "Taime")
            i.putExtra("paused", args["paused"] as Boolean? ?: false)
            i.putExtra("pomodoro", args["pomodoro"] as Boolean? ?: false)
            i.putExtra("color", (args["color"] as Number?)?.toInt() ?: 0xFF93C4A0.toInt())
            i.putExtra("workedMs", long("workedMs"))
            i.putExtra("stampMs", long("stampMs"))
            i.putExtra("pauseStartMs", long("pauseStartMs"))
            i.putExtra("segmentStartMs", long("segmentStartMs"))
            i.putExtra("pomoMs", long("pomoMs"))
            i.putExtra("deadlineMs", long("deadlineMs"))
            @Suppress("UNCHECKED_CAST")
            i.putExtra("art", ArrayList((args["art"] as List<String?>?)?.map { it ?: "" } ?: emptyList()))
            @Suppress("UNCHECKED_CAST")
            i.putExtra("stageNames", ArrayList((args["stageNames"] as List<String>?) ?: emptyList()))
            @Suppress("UNCHECKED_CAST")
            i.putExtra("stageMinutes", ((args["stageMinutes"] as List<Number>?) ?: emptyList()).map { it.toInt() }.toIntArray())
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("live", true).apply()
            try {
                ContextCompat.startForegroundService(ctx, i)
            } catch (_: Exception) {
                // Refused from the background: the next update brings it back.
            }
        }

        fun stop(ctx: Context) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("live", false).apply()
            ctx.stopService(Intent(ctx, LiveService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var last: Intent? = null
    private var deadlineFired = 0L
    private val tick = object : Runnable {
        override fun run() {
            last?.let { render(it) }
            handler.postDelayed(this, 30_000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (val action = intent?.action) {
            "update" -> {
                last = intent
                render(intent)
                handler.removeCallbacks(tick)
                handler.postDelayed(tick, 30_000)
            }
            "pause", "resume", "stop" -> TaimeNativePlugin.dispatchAction(this, action)
            else -> if (last == null) stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.deleteNotificationChannel("taime_live") // 2.0's media-style channel
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

    private fun bitmap(path: String?): Bitmap? =
        if (path.isNullOrEmpty()) null else try {
            BitmapFactory.decodeFile(path)
        } catch (_: Exception) {
            null
        }

    private fun render(i: Intent) {
        ensureChannel()
        val now = System.currentTimeMillis()
        val title = i.getStringExtra("title") ?: "Taime"
        val paused = i.getBooleanExtra("paused", false)
        val pomodoro = i.getBooleanExtra("pomodoro", false)
        val color = i.getIntExtra("color", 0xFF93C4A0.toInt())
        val stamp = i.getLongExtra("stampMs", now)
        val workedAtStamp = i.getLongExtra("workedMs", 0L)
        val worked = if (paused) workedAtStamp else workedAtStamp + (now - stamp)
        val pauseStart = i.getLongExtra("pauseStartMs", now)
        val segStart = i.getLongExtra("segmentStartMs", now)
        val pomoMs = i.getLongExtra("pomoMs", 0L)
        val deadline = i.getLongExtra("deadlineMs", 0L)
        val art = i.getStringArrayListExtra("art") ?: arrayListOf()
        val names = i.getStringArrayListExtra("stageNames") ?: arrayListOf()
        val stageMin = i.getIntArrayExtra("stageMinutes") ?: intArrayOf(0, 10, 25, 45, 60)

        // A deadline passed while nobody was looking: let Dart apply it.
        if (deadline in 1..now && deadlineFired != deadline) {
            deadlineFired = deadline
            TaimeNativePlugin.dispatchAction(this, "tick")
        }

        val hour = 3_600_000L
        val inHourMin = (worked % hour) / 60_000.0
        var stage = 0
        for (k in stageMin.indices) if (inHourMin >= stageMin[k]) stage = k
        val adults = (worked / hour).toInt()
        val stageName = names.getOrNull(stage) ?: ""
        val subtitle = when {
            paused -> "In pausa · lavoro ${fmt(worked)}"
            pomodoro -> "Pomodoro · $stageName"
            adults > 0 -> "$stageName · $adults ${if (adults == 1) "gatto" else "gatti"} nel recinto"
            else -> stageName
        }
        val kitten = bitmap(if (paused) art.getOrNull(5) else art.getOrNull(stage))

        val progress = when {
            pomodoro && pomoMs > 0 -> (((now - (if (paused) pauseStart else segStart)).toDouble() / pomoMs) * 1000).toInt()
            else -> ((worked % hour).toDouble() / hour * 1000).toInt()
        }.coerceIn(0, 1000)

        // Chronometer bases are in elapsedRealtime.
        val elapsedNow = SystemClock.elapsedRealtime()
        val chronoBase = if (paused) elapsedNow - (now - pauseStart) else elapsedNow - worked
        val tint = if (paused) 0xFFE9A15F.toInt() else color

        fun views(layout: Int): RemoteViews {
            val v = RemoteViews(packageName, layout)
            v.setTextViewText(R.id.taime_title, if (paused) "In pausa · $title" else title)
            v.setTextViewText(R.id.taime_subtitle, subtitle)
            v.setChronometer(R.id.taime_chrono, chronoBase, null, true)
            if (kitten != null) v.setImageViewBitmap(R.id.taime_kitten, kitten)
            if (layout == R.layout.taime_live_big) {
                v.setProgressBar(R.id.taime_progress, 1000, progress, false)
                if (Build.VERSION.SDK_INT >= 31) {
                    v.setColorStateList(R.id.taime_progress, "setProgressTintList", ColorStateList.valueOf(tint))
                }
                v.setViewVisibility(R.id.taime_pause_dot, if (paused) View.VISIBLE else View.GONE)
            }
            return v
        }

        val toggle = if (paused) {
            NotificationCompat.Action(R.drawable.ic_taime_play, "Riprendi", servicePending("resume", 1))
        } else {
            NotificationCompat.Action(R.drawable.ic_taime_pause, "Pausa", servicePending("pause", 2))
        }
        val stop = NotificationCompat.Action(R.drawable.ic_taime_stop, "Termina", servicePending("stop", 3))

        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_taime_notif)
            .setColor(tint)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setCustomContentView(views(R.layout.taime_live_small))
            .setCustomBigContentView(views(R.layout.taime_live_big))
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setContentIntent(openAppPending())
            .addAction(toggle)
            .addAction(stop)
            .build()

        val type = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, NOTIF_ID, n, type)
    }

    private fun fmt(ms: Long): String {
        val m = ms / 60_000
        return if (m >= 60) "${m / 60}h ${m % 60}m" else "${m}m"
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
