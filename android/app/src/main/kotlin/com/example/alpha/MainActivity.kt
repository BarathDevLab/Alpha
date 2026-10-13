package com.example.alpha

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_CONTROL  = "control"
        private const val CHANNEL_SOUND    = "sound_events"
        private const val CHANNEL_TEXT     = "text_events"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── EventChannel: sound alerts ────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SOUND)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    SoundGuardService.eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    SoundGuardService.eventSink = null
                }
            })

        // ── EventChannel: text events (Mind Guard) ────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_TEXT)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    MindGuardService.eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    MindGuardService.eventSink = null
                }
            })

        // ── MethodChannel: start / stop / isEnabled ───────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CONTROL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSound" -> {
                        startForegroundService(
                            Intent(this, SoundGuardService::class.java)
                        )
                        result.success(true)
                    }
                    "stopSound" -> {
                        stopService(Intent(this, SoundGuardService::class.java))
                        result.success(true)
                    }
                    "startMind" -> {
                        // Accessibility service is started by the OS; we just record intent
                        getSharedPreferences("safesense_prefs", MODE_PRIVATE)
                            .edit().putBoolean("mind_enabled", true).apply()
                        result.success(true)
                    }
                    "stopMind" -> {
                        getSharedPreferences("safesense_prefs", MODE_PRIVATE)
                            .edit().putBoolean("mind_enabled", false).apply()
                        MindGuardService.eventSink = null
                        result.success(true)
                    }
                    "isEnabled" -> {
                        val prefs = getSharedPreferences("safesense_prefs", MODE_PRIVATE)
                        result.success(mapOf(
                            "sound" to isSoundGuardRunning(),
                            "mind"  to prefs.getBoolean("mind_enabled", false)
                        ))
                    }
                    "getFcmToken" -> {
                        com.google.firebase.messaging.FirebaseMessaging.getInstance().token
                            .addOnSuccessListener { token -> result.success(token) }
                            .addOnFailureListener { result.error("FCM_ERROR", it.message, null) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isSoundGuardRunning(): Boolean {
        val manager = getSystemService(android.app.ActivityManager::class.java)
        return manager.getRunningServices(Integer.MAX_VALUE).any {
            it.service.className == SoundGuardService::class.java.name
        }
    }
}
