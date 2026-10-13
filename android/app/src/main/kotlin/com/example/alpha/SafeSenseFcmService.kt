package com.example.alpha

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import android.util.Log

/**
 * Receives FCM messages when the app is in background/killed.
 * The care-contact receives only a level integer — never text or audio.
 */
class SafeSenseFcmService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "SafeSenseFCM"
        // Expose token to MainActivity via a simple callback
        var onNewToken: ((String) -> Unit)? = null
    }

    override fun onNewToken(token: String) {
        Log.i(TAG, "FCM token refreshed")
        onNewToken?.invoke(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val level = message.data["level"] ?: return
        Log.i(TAG, "FCM alert received — level $level")
        // Forward to Flutter via MethodChannel if app is in foreground
        // (handled in MainActivity via onMessageReceived broadcast)
    }
}
