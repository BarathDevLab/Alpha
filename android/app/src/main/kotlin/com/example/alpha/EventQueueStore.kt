package com.example.alpha

import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Lightweight offline queue for event JSON payloads.
 * Events are persisted in SharedPreferences as a JSON array string.
 * A ConnectivityManager.NetworkCallback flushes the queue on reconnect.
 */
class EventQueueStore(private val context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("event_queue", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(Dispatchers.IO)
    private val backendUrl = "http://10.0.2.2:3000/events"   // emulator → host

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            scope.launch { flushAll() }
        }
    }

    init {
        registerNetworkCallback()
    }

    /** Persist an event payload for later delivery. */
    fun enqueue(eventJson: String) {
        synchronized(this) {
            val arr = loadQueue()
            arr.put(eventJson)
            saveQueue(arr)
        }
        // Try immediate send; if it fails it stays queued.
        scope.launch { flushAll() }
    }

    /** Attempt to POST all queued events to the backend. */
    private suspend fun flushAll() {
        val arr = synchronized(this) { loadQueue() }
        if (arr.length() == 0) return

        val sent = mutableListOf<Int>()
        for (i in 0 until arr.length()) {
            val payload = arr.optString(i)
            if (postEvent(payload)) sent.add(i)
        }

        if (sent.isNotEmpty()) {
            synchronized(this) {
                val current = loadQueue()
                val remaining = JSONArray()
                for (i in 0 until current.length()) {
                    if (i !in sent) remaining.put(current.optString(i))
                }
                saveQueue(remaining)
            }
        }
    }

    /** Returns true if the POST succeeded (2xx). */
    private fun postEvent(payload: String): Boolean = try {
        val url = URL(backendUrl)
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true
        conn.connectTimeout = 4_000
        conn.readTimeout = 4_000
        OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(payload) }
        conn.responseCode in 200..299
    } catch (e: Exception) {
        false
    }

    private fun loadQueue(): JSONArray {
        val raw = prefs.getString("queue", "[]") ?: "[]"
        return try { JSONArray(raw) } catch (e: Exception) { JSONArray() }
    }

    private fun saveQueue(arr: JSONArray) {
        prefs.edit().putString("queue", arr.toString()).apply()
    }

    private fun registerNetworkCallback() {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val req = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        try {
            cm.registerNetworkCallback(req, networkCallback)
        } catch (e: Exception) {
            // Already registered — ignore
        }
    }

    fun destroy() {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        try { cm.unregisterNetworkCallback(networkCallback) } catch (e: Exception) { }
    }
}
