package com.example.heart

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val EVENT_CHANNEL = "com.healthconnect.dashboard/health_updates"
    private val METHOD_CHANNEL = "com.healthconnect.dashboard/health_methods"

    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup EventChannel for streaming health data
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // Setup MethodChannel for control commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isHealthConnectAvailable" -> {
                        try {
                            val packageName = "com.google.android.apps.healthdata"
                            val pm = this.packageManager
                            pm.getPackageInfo(packageName, 0)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "listHealthPackages" -> {
                        try {
                            val pm = this.packageManager
                            val packages = pm.getInstalledPackages(0)
                                .map { it.packageName }
                                .filter { it.contains("health", ignoreCase = true) }
                            result.success(ArrayList(packages))
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "startPassiveListener" -> {
                        try {
                            // Start the passive listener service
                            HealthConnectPassiveService.startPassiveMonitoring(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "stopPassiveListener" -> {
                        try {
                            HealthConnectPassiveService.stopPassiveMonitoring(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle intent if app was opened from Health Connect
        intent?.let { handleIntent(it) }
    }

    private fun handleIntent(intent: android.content.Intent) {
        // Handle any Health Connect related intents
        if (intent.action == "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE") {
            // Show permissions rationale if needed
        }
    }
}