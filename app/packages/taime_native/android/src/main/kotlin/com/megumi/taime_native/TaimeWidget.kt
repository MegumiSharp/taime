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

/**
 * Home-screen list of today's to-dos: up to five rows with a circle to tick
 * them off (through Dart, like the notification buttons), "+" for a new one.
 */
class TaimeTodoWidget : AppWidgetProvider() {

    companion object {
        private const val ACTION = "com.megumi.taime_native.TODO_WIDGET"
        private const val ROWS = 5
        private val rowIds = intArrayOf(R.id.t_row0, R.id.t_row1, R.id.t_row2, R.id.t_row3, R.id.t_row4)
        private val checkIds = intArrayOf(R.id.t_check0, R.id.t_check1, R.id.t_check2, R.id.t_check3, R.id.t_check4)
        private val titleIds = intArrayOf(R.id.t_title0, R.id.t_title1, R.id.t_title2, R.id.t_title3, R.id.t_title4)
        private val metaIds = intArrayOf(R.id.t_meta0, R.id.t_meta1, R.id.t_meta2, R.id.t_meta3, R.id.t_meta4)

        /** args: items = [{id, title, meta, late}], total. */
        fun save(ctx: Context, args: Map<String, Any?>) {
            @Suppress("UNCHECKED_CAST")
            val items = (args["items"] as List<Map<String, Any?>>?) ?: emptyList()
            val arr = org.json.JSONArray()
            for (it in items) {
                arr.put(
                    org.json.JSONObject()
                        .put("id", (it["id"] as Number).toInt())
                        .put("title", it["title"] as String? ?: "")
                        .put("meta", it["meta"] as String? ?: "")
                        .put("late", it["late"] as Boolean? ?: false)
                )
            }
            ctx.getSharedPreferences(LiveService.PREFS, Context.MODE_PRIVATE).edit()
                .putString("todo_items", arr.toString())
                .putInt("todo_total", (args["total"] as Number?)?.toInt() ?: items.size)
                .apply()
            refresh(ctx)
        }

        fun refresh(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, TaimeTodoWidget::class.java))
            if (ids.isEmpty()) return
            val views = build(ctx)
            for (id in ids) mgr.updateAppWidget(id, views)
        }

        private fun open(ctx: Context, target: String, code: Int): PendingIntent? {
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
            launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            launch.putExtra(TaimeNativePlugin.EXTRA_OPEN, target)
            return PendingIntent.getActivity(ctx, code, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        private fun build(ctx: Context): RemoteViews {
            val p = ctx.getSharedPreferences(LiveService.PREFS, Context.MODE_PRIVATE)
            val items = try {
                org.json.JSONArray(p.getString("todo_items", "[]"))
            } catch (_: Exception) {
                org.json.JSONArray()
            }
            val total = p.getInt("todo_total", items.length())
            val v = RemoteViews(ctx.packageName, R.layout.taime_todo_widget)
            v.setTextViewText(R.id.t_header, if (total > 0) "Oggi · $total" else "Oggi")
            v.setViewVisibility(R.id.t_empty, if (items.length() == 0) View.VISIBLE else View.GONE)
            val late = ctx.getColor(R.color.taime_widget_late)
            val muted = ctx.getColor(R.color.taime_widget_muted)
            for (i in 0 until ROWS) {
                if (i >= items.length()) {
                    v.setViewVisibility(rowIds[i], View.GONE)
                    continue
                }
                val it = items.getJSONObject(i)
                v.setViewVisibility(rowIds[i], View.VISIBLE)
                v.setTextViewText(titleIds[i], it.optString("title"))
                v.setTextViewText(metaIds[i], it.optString("meta"))
                v.setTextColor(metaIds[i], if (it.optBoolean("late")) late else muted)
                v.setOnClickPendingIntent(
                    checkIds[i],
                    PendingIntent.getBroadcast(
                        ctx, 40 + i,
                        Intent(ctx, TaimeTodoWidget::class.java).setAction(ACTION)
                            .putExtra("what", "todo:done:${it.getInt("id")}"),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                )
                open(ctx, "todo", 50 + i)?.let { pi -> v.setOnClickPendingIntent(titleIds[i], pi) }
            }
            val more = total - minOf(items.length(), ROWS)
            v.setViewVisibility(R.id.t_more, if (more > 0) View.VISIBLE else View.GONE)
            v.setTextViewText(R.id.t_more, "e altri $more")
            open(ctx, "todo:new", 48)?.let { v.setOnClickPendingIntent(R.id.t_add, it) }
            open(ctx, "todo", 49)?.let { v.setOnClickPendingIntent(R.id.t_root, it) }
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
        TaimeTodoWidget.refresh(context)
        if (context.getSharedPreferences(LiveService.PREFS, Context.MODE_PRIVATE).getBoolean("live", false)) {
            HeadlessRunner.run(context.applicationContext, "tick")
        }
    }
}
