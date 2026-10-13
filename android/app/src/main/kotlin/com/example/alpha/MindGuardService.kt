package com.example.alpha

import android.accessibilityservice.AccessibilityService
import android.content.SharedPreferences
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import org.json.JSONObject
import java.util.UUID

/**
 * Mind Guard Accessibility Service.
 *
 * Listens to TYPE_VIEW_TEXT_CHANGED events.
 * - Only processes events from allowlisted packages.
 * - Skips password nodes.
 * - Batches text fragments and emits to Flutter EventChannel every 500 ms.
 * - Never stores raw text; only the event JSON (label + level) is posted to backend.
 */
class MindGuardService : AccessibilityService() {

    companion object {
        private const val TAG = "MindGuard"
        private const val BATCH_INTERVAL_MS = 500L

        // Default allowlist — owner can extend via Settings > SharedPreferences
        private val DEFAULT_ALLOWLIST = setOf(
            "com.android.chrome",
            "org.chromium.chrome",
            "com.google.android.apps.docs",
            "com.simplenote",
            "com.microsoft.teams",
            "com.google.android.gm"
        )

        // Shared sink for Flutter EventChannel (set by MainActivity)
        var eventSink: EventChannel.EventSink? = null
    }

    private val serviceScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val pendingText = StringBuilder()
    private var batchJob: Job? = null
    private lateinit var prefs: SharedPreferences

    override fun onServiceConnected() {
        prefs = getSharedPreferences("safesense_prefs", MODE_PRIVATE)
        Log.i(TAG, "Mind Guard connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) return

        val pkg = event.packageName?.toString() ?: return
        if (!isAllowlisted(pkg)) return

        val nodeInfo = event.source ?: return
        if (nodeInfo.isPassword) {
            nodeInfo.recycle()
            return
        }

        val text = event.text.joinToString(" ").trim()
        nodeInfo.recycle()
        if (text.isBlank()) return

        // Accumulate text; debounce sending to Flutter
        synchronized(pendingText) {
            pendingText.append(" ").append(text)
        }

        batchJob?.cancel()
        batchJob = serviceScope.launch {
            delay(BATCH_INTERVAL_MS)
            flush()
        }
    }

    private fun flush() {
        val text = synchronized(pendingText) {
            val t = pendingText.toString().trim()
            pendingText.clear()
            t
        }
        if (text.isBlank()) return

        val json = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("type", "mind")
            put("text", text)          // text stays on device — classifier runs in Dart
            put("ts", java.time.Instant.now().toString())
        }.toString()

        Log.d(TAG, "Text event dispatched (${text.length} chars)")

        serviceScope.launch(Dispatchers.Main) {
            eventSink?.success(json)
        }
    }

    private fun isAllowlisted(pkg: String): Boolean {
        val custom = prefs.getStringSet("mind_allowlist", null)
        val list = if (custom != null && custom.isNotEmpty()) custom else DEFAULT_ALLOWLIST
        return list.contains(pkg)
    }

    override fun onInterrupt() {
        Log.i(TAG, "Mind Guard interrupted")
    }

    override fun onDestroy() {
        serviceScope.cancel()
        super.onDestroy()
    }
}
