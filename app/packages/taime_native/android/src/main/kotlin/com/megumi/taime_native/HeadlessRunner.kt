package com.megumi.taime_native

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * With no UI engine alive, a notification or widget button boots a small engine that
 * runs `liveActionMain(action)` from main.dart, which updates the database and
 * the notification, then calls `bg.done`.
 */
object HeadlessRunner {
    private val main = Handler(Looper.getMainLooper())
    private val engines = mutableListOf<FlutterEngine>()

    fun run(context: Context, action: String) {
        main.post {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val engine = FlutterEngine(context)
            engines.add(engine)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "liveActionMain"),
                listOf(action)
            )
            // Safety net if Dart never reports back.
            main.postDelayed({ destroy(engine) }, 30_000)
        }
    }

    /** One run finished: close the oldest engine (runs finish in order), not
     *  every engine, so two quick taps do not cut each other short. */
    fun done() {
        main.postDelayed({ engines.firstOrNull()?.let { destroy(it) } }, 500)
    }

    private fun destroy(engine: FlutterEngine) {
        if (engines.remove(engine)) engine.destroy()
    }
}
