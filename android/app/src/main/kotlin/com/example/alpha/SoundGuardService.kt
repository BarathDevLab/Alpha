package com.example.alpha

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONObject
import java.util.UUID
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Sound Guard foreground service.
 *
 * Pipeline:
 *  AudioRecord (16 kHz, mono, PCM16)
 *  → sliding window 15 600 samples, hop 8 000 samples (0.5 s)
 *  → normalise to float32 [-1, 1]
 *  → YamNetHelper.infer()
 *  → speech gate (drop if Speech score > 0.5)
 *  → multi-frame trigger (alert class > 0.5 in 3 of last 5 frames)
 *  → 30 s per-class cooldown
 *  → emit JSON via EventChannel + POST to backend
 */
class SoundGuardService : Service() {

    companion object {
        private const val TAG = "SoundGuard"
        private const val NOTIF_CHANNEL = "safesense_persistent"
        private const val NOTIF_ID = 1001

        // Sliding window parameters
        private const val SAMPLE_RATE = 16_000
        private const val WINDOW = 15_600      // 0.975 s
        private const val HOP = 8_000          // 0.5 s

        // Detection thresholds
        private const val SCORE_THRESHOLD = 0.5f
        private const val SPEECH_GATE = 0.5f
        private const val FRAMES_NEEDED = 3
        private const val FRAME_WINDOW = 5
        private const val COOLDOWN_MS = 30_000L

        // dB offset (approximate — not calibrated)
        private const val DB_OFFSET = 70.0

        // Geohash placeholder (Chennai area for demo)
        private const val DEMO_GEOHASH = "ttnem"

        // Shared sink for the Flutter EventChannel (set by MainActivity)
        var eventSink: io.flutter.plugin.common.EventChannel.EventSink? = null
    }

    private var recorder: AudioRecord? = null
    private var yamNet: YamNetHelper? = null
    private var queue: EventQueueStore? = null
    private val serviceScope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Ring buffer of recent frames per alert class index:  classIdx → deque of booleans
    private val frameHistory = mutableMapOf<Int, ArrayDeque<Boolean>>()

    // Per-class cooldown: classIdx → last alert timestamp
    private val lastAlertMs = mutableMapOf<Int, Long>()

    // Accumulation buffer for sliding window
    private val ringBuffer = ShortArray(WINDOW * 2)
    private var ringHead = 0
    private var bufferedSamples = 0

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        yamNet = YamNetHelper(applicationContext)
        queue = EventQueueStore(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startCapture()
        return START_STICKY
    }

    override fun onDestroy() {
        serviceScope.cancel()
        recorder?.apply { stop(); release() }
        recorder = null
        yamNet?.close()
        queue?.destroy()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Audio capture loop ────────────────────────────────────────────────────

    private fun startCapture() {
        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        val bufSize = maxOf(minBuf, HOP * 2)

        recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufSize * 2
        )

        if (recorder?.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "AudioRecord init failed — permission missing?")
            stopSelf()
            return
        }

        recorder?.startRecording()
        Log.i(TAG, "AudioRecord started")

        serviceScope.launch {
            val chunk = ShortArray(HOP)
            while (isActive) {
                val read = recorder?.read(chunk, 0, HOP) ?: break
                if (read > 0) processChunk(chunk, read)
            }
        }
    }

    // ── Frame processing ──────────────────────────────────────────────────────

    private fun processChunk(chunk: ShortArray, len: Int) {
        // Append to ring buffer
        for (i in 0 until len) {
            ringBuffer[(ringHead + bufferedSamples) % ringBuffer.size] = chunk[i]
            if (bufferedSamples < WINDOW) bufferedSamples++ else ringHead = (ringHead + 1) % ringBuffer.size
        }

        if (bufferedSamples < WINDOW) return   // not enough data yet

        // Materialise current window and normalise to [-1, 1]
        val floats = FloatArray(WINDOW) { i ->
            ringBuffer[(ringHead + i) % ringBuffer.size] / 32768f
        }

        val yamNet = yamNet ?: return
        val (scores, _) = yamNet.infer(floats)

        // ── Speech gate ───────────────────────────────────────────────────────
        if (scores[yamNet.speechIndex] > SPEECH_GATE) {
            Log.d(TAG, "Speech gate drop (score=${scores[yamNet.speechIndex]})")
            return
        }

        // ── dB (approx) ──────────────────────────────────────────────────────
        val rms = sqrt(floats.map { it * it }.average()).toFloat()
        val db = if (rms > 0f) 20.0 * log10(rms) + DB_OFFSET else 0.0

        // ── Multi-frame trigger ───────────────────────────────────────────────
        val now = System.currentTimeMillis()
        for (classIdx in yamNet.alertIndices) {
            val score = scores[classIdx]
            val history = frameHistory.getOrPut(classIdx) { ArrayDeque() }
            history.addLast(score > SCORE_THRESHOLD)
            if (history.size > FRAME_WINDOW) history.removeFirst()

            val hits = history.count { it }
            if (hits >= FRAMES_NEEDED) {
                val lastAlert = lastAlertMs[classIdx] ?: 0L
                if (now - lastAlert >= COOLDOWN_MS) {
                    lastAlertMs[classIdx] = now
                    val label = yamNet.className(classIdx)
                    val level = scoreToLevel(score)
                    emitEvent(label, level, score, db)
                    history.clear()   // reset after trigger
                }
            }
        }
    }

    // ── Event emission ────────────────────────────────────────────────────────

    private fun emitEvent(label: String, level: Int, confidence: Float, db: Double) {
        val json = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("type", "sound")
            put("label", label)
            put("level", level)
            put("confidence", confidence.toDouble())
            put("db", String.format("%.1f approx", db))
            put("geohash", DEMO_GEOHASH)
            put("ts", java.time.Instant.now().toString())
        }.toString()

        Log.i(TAG, "Alert: $json")

        // Push to Flutter EventChannel (must be on main thread)
        serviceScope.launch(Dispatchers.Main) {
            eventSink?.success(json)
        }

        // POST to backend (offline-queue handles failures)
        queue?.enqueue(json)
    }

    private fun scoreToLevel(score: Float): Int = when {
        score >= 0.85f -> 3
        score >= 0.65f -> 2
        else           -> 1
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            NOTIF_CHANNEL,
            "SafeSense monitoring",
            NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Persistent monitoring status" }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification =
        Notification.Builder(this, NOTIF_CHANNEL)
            .setContentTitle(getString(R.string.sound_guard_notification_title))
            .setContentText(getString(R.string.sound_guard_notification_text))
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
}
