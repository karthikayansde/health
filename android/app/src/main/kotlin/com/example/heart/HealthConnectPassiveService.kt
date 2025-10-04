package com.example.heart

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log

/**
 * Minimal passive monitoring service placeholder.
 * This provides static helper methods used by MainActivity and a basic Service implementation
 * so the service name referenced in the AndroidManifest.xml exists and Kotlin compiles.
 */
class HealthConnectPassiveService : Service() {
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("HealthConnectService", "Passive service started: $intent")

        // Handle Health Connect passive monitoring update intents and forward to Flutter.
        try {
            val action = intent?.action
            if (action == "androidx.health.ACTION_PASSIVE_MONITORING_UPDATE") {
                Log.d("HealthConnectService", "Received passive monitoring update intent")

                val payload = HashMap<String, Any?>()
                val extras = intent.extras
                if (extras != null) {
                    val keys = extras.keySet()
                    for (key in keys) {
                        try {
                            val value = extras.get(key)
                            // Convert non-primitive types to string safely
                            when (value) {
                                is java.lang.Integer,
                                is java.lang.Long,
                                is java.lang.Double,
                                is java.lang.Float,
                                is java.lang.Boolean,
                                is java.lang.String -> payload[key] = value
                                else -> payload[key] = value?.toString()
                            }
                        } catch (e: Exception) {
                            Log.w("HealthConnectService", "Failed to read extra $key", e)
                        }
                    }
                }

                // Include a timestamp for the event
                payload["_receivedTimestamp"] = System.currentTimeMillis()

                // Send to Flutter via the EventChannel sink in MainActivity (if available)
                try {
                    MainActivity.eventSink?.success(payload)
                    Log.d("HealthConnectService", "Forwarded passive update to Flutter: $payload")
                } catch (e: Exception) {
                    Log.e("HealthConnectService", "Failed to forward event to Flutter", e)
                }
            }
        } catch (e: Exception) {
            Log.e("HealthConnectService", "Error handling intent", e)
        }

        // Keep the service running; passive updates will be delivered via intents
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("HealthConnectService", "Passive service destroyed")
    }

    companion object {
        private const val TAG = "HealthConnectPassiveService"

        fun startPassiveMonitoring(context: Context) {
            try {
                val intent = Intent(context, HealthConnectPassiveService::class.java)
                context.startService(intent)
                Log.d(TAG, "Requested start of passive monitoring service")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start passive monitoring", e)
                throw e
            }
        }

        fun stopPassiveMonitoring(context: Context) {
            try {
                val intent = Intent(context, HealthConnectPassiveService::class.java)
                context.stopService(intent)
                Log.d(TAG, "Requested stop of passive monitoring service")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop passive monitoring", e)
                throw e
            }
        }
    }
}
