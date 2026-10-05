package com.megumi.taime_native

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

/**
 * Taime's native side:
 *  - live.update / live.stop: the focus notification ([LiveService]);
 *  - registerUi: marks the engine that shows the UI, so notification and
 *    widget buttons reach it directly; with no UI alive they start a headless
 *    engine;
 *  - widget.update / todoWidget.update: the two home-screen widgets;
 *  - notif.status / settings.open: the notification check in Impostazioni;
 *  - open.consume: which screen a widget tap asked for;
 *  - update.abi / update.install: "Cerca aggiornamenti";
 *  - sound.*: system sound picker, alarm-stream preview, shareable file uris.
 */
class TaimeNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener, PluginRegistry.NewIntentListener {

    companion object {
        @Volatile
        var uiChannel: MethodChannel? = null
        private val main = Handler(Looper.getMainLooper())
        private const val REQ_PICK = 4711

        /** Extra on launch intents: which screen to open ("todo", "todo:new"). */
        const val EXTRA_OPEN = "taime_open"

        /** A notification button was pressed: run it in Dart. */
        fun dispatchAction(context: Context, action: String) {
            val ch = uiChannel
            if (ch != null) {
                main.post { ch.invokeMethod("action", action) }
            } else {
                HeadlessRunner.run(context.applicationContext, action)
            }
        }
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPick: MethodChannel.Result? = null
    private var pendingOpen: String? = null
    private var player: MediaPlayer? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "taime_native")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (uiChannel === channel) uiChannel = null
        channel.setMethodCallHandler(null)
        stopPreview()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "registerUi" -> {
                    uiChannel = channel
                    result.success(null)
                }
                "live.update" -> {
                    @Suppress("UNCHECKED_CAST")
                    LiveService.update(context, call.arguments as Map<String, Any?>)
                    result.success(null)
                }
                "live.stop" -> {
                    LiveService.stop(context)
                    result.success(null)
                }
                "bg.done" -> {
                    HeadlessRunner.done()
                    result.success(null)
                }
                "backup.save" -> {
                    saveBackup(call.argument<String>("name")!!, call.argument<ByteArray>("bytes")!!)
                    result.success(null)
                }
                "widget.update" -> {
                    @Suppress("UNCHECKED_CAST")
                    TaimeWidget.save(context, call.arguments as Map<String, Any?>)
                    result.success(null)
                }
                "todoWidget.update" -> {
                    @Suppress("UNCHECKED_CAST")
                    TaimeTodoWidget.save(context, call.arguments as Map<String, Any?>)
                    result.success(null)
                }
                "notif.status" -> result.success(notificationStatus())
                "settings.open" -> {
                    openSettings(call.argument<String>("what")!!, call.argument<String>("channel"))
                    result.success(null)
                }
                "open.consume" -> {
                    result.success(pendingOpen)
                    pendingOpen = null
                }
                "update.abi" -> result.success(if (Build.SUPPORTED_ABIS.firstOrNull()?.startsWith("arm64") == true) "arm64" else "arm32")
                "update.install" -> result.success(installApk(call.arguments as String))
                "sound.pickSystem" -> pickSystemSound(call.argument<String>("current"), result)
                "sound.shareableUri" -> result.success(shareableUri(call.arguments as String))
                "sound.preview" -> {
                    preview(call.argument<String>("kind")!!, call.argument<String>("value")!!)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("taime", e.message, null)
        }
    }

    // --- Sounds -------------------------------------------------------------

    private fun pickSystemSound(current: String?, result: MethodChannel.Result) {
        val act = activity ?: return result.error("taime", "no activity", null)
        pendingPick?.success(null)
        pendingPick = result
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALL)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Suono dei promemoria")
            if (current != null) putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
        }
        act.startActivityForResult(intent, REQ_PICK)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_PICK) return false
        val res = pendingPick ?: return true
        pendingPick = null
        val uri: Uri? = if (resultCode == Activity.RESULT_OK && data != null) {
            @Suppress("DEPRECATION")
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        } else null
        if (uri == null) {
            res.success(null)
        } else {
            val title = try {
                RingtoneManager.getRingtone(context, uri)?.getTitle(context) ?: "Suono del telefono"
            } catch (e: Exception) {
                "Suono del telefono"
            }
            res.success(mapOf("uri" to uri.toString(), "title" to title))
        }
        return true
    }

    /** A content:// uri the system UI may read, for a file in files/sounds. */
    private fun shareableUri(path: String): String {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.taime.files", File(path))
        for (pkg in listOf("com.android.systemui", "android")) {
            context.grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return uri.toString()
    }

    private fun soundUri(kind: String, value: String): Uri = if (kind == "bundled") {
        val id = context.resources.getIdentifier(value, "raw", context.packageName)
        Uri.parse("android.resource://${context.packageName}/$id")
    } else {
        Uri.parse(value)
    }

    /** Plays on the alarm stream, like the real reminder will. */
    private fun preview(kind: String, value: String) {
        stopPreview()
        val mp = MediaPlayer()
        mp.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        mp.setDataSource(context, soundUri(kind, value))
        mp.setOnCompletionListener { stopPreview() }
        mp.prepare()
        mp.start()
        player = mp
        main.postDelayed({ if (player === mp) stopPreview() }, 8000)
    }

    private fun stopPreview() {
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
    }

    // --- Notification check ----------------------------------------------------

    private fun notificationStatus(): Map<String, Any?> {
        val nm = context.getSystemService(NotificationManager::class.java)
        val am = context.getSystemService(AlarmManager::class.java)
        val pm = context.getSystemService(PowerManager::class.java)
        val channels = if (Build.VERSION.SDK_INT >= 26) {
            nm.notificationChannels.map {
                mapOf("id" to it.id, "name" to it.name.toString(), "importance" to it.importance)
            }
        } else emptyList()
        val brand = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        return mapOf(
            "enabled" to NotificationManagerCompat.from(context).areNotificationsEnabled(),
            "exact" to (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()),
            "fullScreen" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
            "battery" to pm.isIgnoringBatteryOptimizations(context.packageName),
            "xiaomi" to (brand.contains("xiaomi") || brand.contains("redmi") || brand.contains("poco")),
            "channels" to channels,
        )
    }

    /** Opens the system page that fixes [what]; the app page when there is none. */
    private fun openSettings(what: String, channel: String?) {
        val pkg = context.packageName
        val appPage = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))
        val intent = when (what) {
            "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
            "channel" -> if (Build.VERSION.SDK_INT >= 26 && channel != null) {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, channel)
            } else null
            "exact" -> if (Build.VERSION.SDK_INT >= 31) {
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$pkg"))
            } else null
            "fullScreen" -> if (Build.VERSION.SDK_INT >= 34) {
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$pkg"))
            } else null
            "battery" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$pkg"))
            "autostart" -> Intent().setComponent(
                ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
            )
            else -> null
        } ?: appPage
        val starter = activity ?: context
        for (i in listOf(intent, appPage)) {
            if (activity == null) i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                starter.startActivity(i)
                return
            } catch (_: Exception) {
                // Not on this phone: fall back to the app page.
            }
        }
    }

    // --- Updates ---------------------------------------------------------------

    /**
     * Opens Android's installer on a downloaded APK (in cache/updates). False,
     * with the permission page opened instead, until "Installa app
     * sconosciute" is allowed for Taime.
     */
    private fun installApk(path: String): Boolean {
        val pkg = context.packageName
        val intent = if (Build.VERSION.SDK_INT >= 26 && !context.packageManager.canRequestPackageInstalls()) {
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$pkg"))
        } else {
            val uri = FileProvider.getUriForFile(context, "$pkg.taime.files", File(path))
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val act = activity
        if (act != null) act.startActivity(intent) else context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return intent.action == Intent.ACTION_VIEW
    }

    // --- Opening a screen from a widget -----------------------------------------

    private fun takeOpen(intent: Intent?) {
        val target = intent?.getStringExtra(EXTRA_OPEN) ?: return
        intent.removeExtra(EXTRA_OPEN)
        val ui = uiChannel
        if (ui != null) ui.invokeMethod("open", target) else pendingOpen = target
    }

    override fun onNewIntent(intent: Intent): Boolean {
        takeOpen(intent)
        return false
    }

    // --- Backup -------------------------------------------------------------

    /** Download/Taime/<name>; automatic backups beyond the newest 4 are removed. */
    private fun saveBackup(name: String, bytes: ByteArray) {
        if (Build.VERSION.SDK_INT >= 29) {
            val resolver = context.contentResolver
            val collection = android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val folder = android.os.Environment.DIRECTORY_DOWNLOADS + "/Taime/"
            val cols = arrayOf(
                android.provider.MediaStore.MediaColumns._ID,
                android.provider.MediaStore.MediaColumns.DISPLAY_NAME
            )
            // Same name today: replace it.
            resolver.query(
                collection, cols,
                "${android.provider.MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${android.provider.MediaStore.MediaColumns.DISPLAY_NAME}=?",
                arrayOf(folder, name), null
            )?.use { c ->
                while (c.moveToNext()) {
                    resolver.delete(android.content.ContentUris.withAppendedId(collection, c.getLong(0)), null, null)
                }
            }
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, folder)
            }
            val uri = resolver.insert(collection, values) ?: throw IllegalStateException("MediaStore insert failed")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
            // Keep the newest 4 automatic backups.
            resolver.query(
                collection, cols,
                "${android.provider.MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${android.provider.MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?",
                arrayOf(folder, "taime-auto-%"),
                "${android.provider.MediaStore.MediaColumns.DATE_ADDED} DESC"
            )?.use { c ->
                var i = 0
                while (c.moveToNext()) {
                    if (i++ >= 4) {
                        resolver.delete(android.content.ContentUris.withAppendedId(collection, c.getLong(0)), null, null)
                    }
                }
            }
        } else {
            val dir = File(context.getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS), "Taime")
            dir.mkdirs()
            File(dir, name).writeBytes(bytes)
            dir.listFiles { f -> f.name.startsWith("taime-auto-") }
                ?.sortedByDescending { it.lastModified() }
                ?.drop(4)
                ?.forEach { it.delete() }
        }
    }

    // --- Activity plumbing ---------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addOnNewIntentListener(this)
        if (pendingOpen == null) {
            pendingOpen = binding.activity.intent?.getStringExtra(EXTRA_OPEN)
            binding.activity.intent?.removeExtra(EXTRA_OPEN)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        activity = null
    }
}
