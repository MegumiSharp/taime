package com.megumi.taime_native

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * "Bevi acqua": reminders that live apart from the focus timer. Dart computes
 * the plan (when, within which hours, after the last glass) and the counts;
 * here an alarm walks that plan with the app closed, shows the notification
 * (kitten, glasses so far, "Ho bevuto" and "Più tardi"), and turns the screen
 * on. When the plan runs low it asks Dart for more ("water:plan").
 */
object Water {
    private const val PREFS = "taime_water"
    private const val NOTIF_ID = 8
    private const val CHANNEL_PREFIX = "taime_water_"
    private const val COLOR = 0xFF5B9BD5.toInt()

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** Everything Dart knows, pushed after each change; re-arms the alarm. */
    fun update(ctx: Context, a: Map<String, Any?>) {
        @Suppress("UNCHECKED_CAST")
        val plan = (a["plan"] as List<Number>?).orEmpty().joinToString(",") { it.toLong().toString() }
        prefs(ctx).edit()
            .putString("plan", plan)
            .putInt("count", (a["count"] as Number?)?.toInt() ?: 0)
            .putString("day", a["day"] as String? ?: today())
            .putInt("goal", (a["goal"] as Number?)?.toInt() ?: 8)
            .putInt("glass", (a["glass"] as Number?)?.toInt() ?: 250)
            .putInt("snooze", (a["snooze"] as Number?)?.toInt() ?: 15)
            .putString("text", a["text"] as String? ?: "")
            .putString("sound", a["sound"] as String? ?: "default")
            .putString("art", a["art"] as String?)
            .apply()
        arm(ctx)
        // A glass drunk in the app: the notification is answered.
        if (a["drank"] == true) cancelNotification(ctx)
    }

    /** Sets the alarm for the next planned time (or a pending "Più tardi"). */
    fun arm(ctx: Context) {
        val p = prefs(ctx)
        val now = System.currentTimeMillis()
        val plan = plan(ctx).filter { it > now + 30_000 }
        val snooze = p.getLong("snoozeAt", 0L).takeIf { it > now }
        val next = listOfNotNull(plan.firstOrNull(), snooze).minOrNull()
        val am = ctx.getSystemService(AlarmManager::class.java)
        val pi = alarmIntent(ctx, "fire", 0)
        if (next == null) {
            am.cancel(pi)
            return
        }
        setAlarm(ctx, next, pi)
        // Plan almost used up and nobody opened the app: ask for more.
        if (plan.size < 4 && p.getString("plan", "")!!.isNotEmpty()) {
            TaimeNativePlugin.dispatchAction(ctx, "water:plan")
        }
    }

    /** "Prova tra 10 secondi" in the water settings. */
    fun test(ctx: Context) = setAlarm(ctx, System.currentTimeMillis() + 10_000, alarmIntent(ctx, "test", 1))

    private fun plan(ctx: Context): List<Long> =
        prefs(ctx).getString("plan", "")!!.split(',').mapNotNull { it.toLongOrNull() }

    private fun setAlarm(ctx: Context, at: Long, pi: PendingIntent) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    private fun alarmIntent(ctx: Context, action: String, code: Int): PendingIntent = PendingIntent.getBroadcast(
        ctx, 4200 + code,
        Intent(ctx, WaterReceiver::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    private fun count(ctx: Context): Int {
        val p = prefs(ctx)
        return if (p.getString("day", "") == today()) p.getInt("count", 0) else 0
    }

    internal fun onAlarm(ctx: Context, action: String) {
        val p = prefs(ctx)
        when (action) {
            "fire" -> {
                p.edit().remove("snoozeAt").apply()
                // Goal reached: no more nagging today.
                if (count(ctx) < p.getInt("goal", 8)) show(ctx, done = false)
                arm(ctx)
            }
            "test" -> show(ctx, done = false)
            "drink" -> {
                val n = count(ctx) + 1
                p.edit().putInt("count", n).putString("day", today()).remove("snoozeAt").apply()
                show(ctx, done = true)
                TaimeNativePlugin.dispatchAction(ctx, "water:drink")
            }
            "snooze" -> {
                p.edit().putLong("snoozeAt", System.currentTimeMillis() + p.getInt("snooze", 15) * 60_000L).apply()
                cancelNotification(ctx)
                arm(ctx)
            }
        }
    }

    private fun cancelNotification(ctx: Context) =
        ctx.getSystemService(NotificationManager::class.java).cancel(NOTIF_ID)

    private fun liters(ml: Int): String = when {
        ml % 1000 == 0 -> "${ml / 1000} L"
        ml % 100 == 0 -> String.format(Locale.ITALY, "%.1f L", ml / 1000.0)
        else -> String.format(Locale.ITALY, "%.2f L", ml / 1000.0)
    }

    private fun channel(ctx: Context, sound: String): String {
        val id = CHANNEL_PREFIX + sound
        if (Build.VERSION.SDK_INT < 26) return id
        val nm = ctx.getSystemService(NotificationManager::class.java)
        for (c in nm.notificationChannels) {
            if (c.id.startsWith(CHANNEL_PREFIX) && c.id != id) nm.deleteNotificationChannel(c.id)
        }
        if (nm.getNotificationChannel(id) != null) return id
        val ch = NotificationChannel(id, "Bevi acqua", NotificationManager.IMPORTANCE_HIGH)
        ch.description = "Promemoria per bere, indipendenti dal timer"
        ch.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        when (sound) {
            "silent" -> {
                ch.setSound(null, null)
                ch.enableVibration(false)
            }
            "vibrate" -> {
                ch.setSound(null, null)
                ch.enableVibration(true)
            }
            "default" -> {
                ch.setSound(Settings.System.DEFAULT_NOTIFICATION_URI, attrs)
                ch.enableVibration(true)
            }
            else -> {
                val res = ctx.resources.getIdentifier(sound, "raw", ctx.packageName)
                ch.setSound(Uri.parse("android.resource://${ctx.packageName}/$res"), attrs)
                ch.enableVibration(true)
            }
        }
        ch.vibrationPattern = longArrayOf(0, 250, 150, 250)
        nm.createNotificationChannel(ch)
        return id
    }

    /** The reminder, or after "Ho bevuto" a quiet "fatto" that fades away. */
    private fun show(ctx: Context, done: Boolean) {
        val p = prefs(ctx)
        val n = count(ctx)
        val goal = p.getInt("goal", 8)
        val text = p.getString("text", "").orEmpty().ifBlank { "È ora di bere un po' d'acqua" }
        val title = if (done) "Fatto! Un bicchiere in più" else text
        val subtitle = "$n di $goal bicchieri · ${liters(n * p.getInt("glass", 250))}"
        val kitten = p.getString("art", null)?.let {
            try {
                BitmapFactory.decodeFile(it)
            } catch (_: Exception) {
                null
            }
        }

        fun views(big: Boolean): RemoteViews {
            val v = RemoteViews(ctx.packageName, if (big) R.layout.taime_water_big else R.layout.taime_water_small)
            v.setTextViewText(R.id.taime_title, title)
            v.setTextViewText(R.id.taime_subtitle, subtitle)
            if (kitten != null) v.setImageViewBitmap(R.id.taime_kitten, kitten)
            if (big) v.setProgressBar(R.id.taime_progress, goal.coerceAtLeast(1), n.coerceAtMost(goal), false)
            return v
        }

        val b = NotificationCompat.Builder(ctx, channel(ctx, p.getString("sound", "default")!!))
            .setSmallIcon(R.drawable.ic_taime_water)
            .setColor(COLOR)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setCustomContentView(views(false))
            .setCustomBigContentView(views(true))
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        if (open != null) {
            b.setContentIntent(
                PendingIntent.getActivity(ctx, 4210, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            )
        }
        if (done) {
            b.setSilent(true).setOnlyAlertOnce(true).setTimeoutAfter(4000)
        } else {
            b.addAction(R.drawable.ic_taime_water, "Ho bevuto", alarmIntent(ctx, "drink", 2))
            b.addAction(R.drawable.ic_taime_pause, "Più tardi", alarmIntent(ctx, "snooze", 3))
            // Lights the screen up: a full-screen intent to a see-through
            // activity that only turns the screen on and leaves at once.
            b.setFullScreenIntent(
                PendingIntent.getActivity(
                    ctx, 4211,
                    Intent(ctx, WakeActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                ),
                true
            )
            wake(ctx)
        }
        ctx.getSystemService(NotificationManager::class.java).notify(NOTIF_ID, b.build())
    }

    /** Second way to light the screen, for phones that hold back full-screen intents. */
    @Suppress("DEPRECATION")
    private fun wake(ctx: Context) {
        try {
            val pm = ctx.getSystemService(PowerManager::class.java)
            if (pm.isInteractive) return
            pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "taime:water"
            ).acquire(3000)
        } catch (_: Exception) {
        }
    }
}

class WaterReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Water.onAlarm(context, intent.action ?: return)
    }
}

/** Turns the screen on over the lock screen and closes: the notification shows. */
class WakeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
    }

    override fun onResume() {
        super.onResume()
        Handler(Looper.getMainLooper()).postDelayed({ finish() }, 600)
    }
}
