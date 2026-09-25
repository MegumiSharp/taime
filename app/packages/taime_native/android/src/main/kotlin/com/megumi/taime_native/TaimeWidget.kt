package com.megumi.taime_native

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

/**
 * Home-screen widget: the kitten, what you are doing, a live chronometer and
 * one-tap Inizia / Pausa / Termina. Dart pushes its state with widget.update;
 * buttons go through the same path as the notification buttons.
 */
class TaimeWidget : AppWidgetProvider() {

    companion object {
        private const val ACTION = "com.megumi.taime_native.WIDGET"

        fun save(ctx: Context, args: Map<String, Any?>) {
            ctx.getSharedPreferences(LiveService.PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("w_running", args["running"] as Boolean? ?: false)
                .putBoolean("w_paused", args["paused"] as Boolean? ?: false)
                .putString("w_title", args["title"] as String? ?: "Taime")
                .putString("w_subtitle", args["subtitle"] as String? ?: "")
                .putLong("w_since", (args["sinceMs"] as Number?)?.toLong() ?: 0L)
                .putString("w_art", args["artPath"] as String?)
                .apply()
            refresh(ctx)
        }

        fun refresh(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, TaimeWidget::class.java))
            if (ids.isEmpty()) return
            val views = build(ctx)
            for (id in ids) mgr.updateAppWidget(id, views)
        }

        private fun button(ctx: Context, what: String, code: Int): PendingIntent =
            PendingIntent.getBroadcast(
                ctx, code,
                Intent(ctx, TaimeWidget::class.java).setAction(ACTION).putExtra("what", what),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

        private fun build(ctx: Context): RemoteViews {
            val p = ctx.getSharedPreferences(LiveService.PREFS, Context.MODE_PRIVATE)
            val running = p.getBoolean("w_running", false)
            val paused = p.getBoolean("w_paused", false)
            val v = RemoteViews(ctx.packageName, R.layout.taime_widget)
            v.setTextViewText(R.id.w_title, p.getString("w_title", "Taime"))
            v.setTextViewText(R.id.w_subtitle, p.getString("w_subtitle", "Pronto per concentrarti"))
            p.getString("w_art", null)?.let { path ->
                try {
                    BitmapFactory.decodeFile(path)?.let { v.setImageViewBitmap(R.id.w_kitten, it) }
                } catch (_: Exception) {
                }
            }
            if (running) {
                val since = p.getLong("w_since", System.currentTimeMillis())
                val base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - since)
                v.setChronometer(R.id.w_chrono, base, null, true)
                v.setViewVisibility(R.id.w_chrono, View.VISIBLE)
                v.setViewVisibility(R.id.w_start, View.GONE)
                v.setViewVisibility(R.id.w_toggle, View.VISIBLE)
                v.setViewVisibility(R.id.w_stop, View.VISIBLE)
                v.setTextViewText(R.id.w_toggle, if (paused) "Riprendi" else "Pausa")
                v.setOnClickPendingIntent(R.id.w_toggle, button(ctx, if (paused) "resume" else "pause", 21))
                v.setOnClickPendingIntent(R.id.w_stop, button(ctx, "stop", 22))
            } else {
                v.setViewVisibility(R.id.w_chrono, View.GONE)
                v.setViewVisibility(R.id.w_start, View.VISIBLE)
                v.setViewVisibility(R.id.w_toggle, View.GONE)
                v.setViewVisibility(R.id.w_stop, View.GONE)
                v.setOnClickPendingIntent(R.id.w_start, button(ctx, "start", 20))
            }
            ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.let { launch ->
                v.setOnClickPendingIntent(
                    R.id.w_root,
                    PendingIntent.getActivity(ctx, 23, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                )
            }
            return v
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        refresh(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION) {
            intent.getStringExtra("what")?.let { TaimeNativePlugin.dispatchAction(context, it) }
            return
        }
        super.onReceive(context, intent)
    }
}

/** After a reboot, bring the focus notification and the widget back. */
class TaimeBootReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != "android.intent.action.QUICKBOOT_POWERON") return
        TaimeWidget.refresh(context)
        if (context.getSharedPreferences(LiveService.PREFS, Context.MODE_PRIVATE).getBoolean("live", false)) {
            HeadlessRunner.run(context.applicationContext, "tick")
        }
    }
}
