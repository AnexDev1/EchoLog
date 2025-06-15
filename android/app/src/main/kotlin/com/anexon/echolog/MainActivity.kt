package com.anexon.echolog // Ensure this matches your package name

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context // Not strictly needed here if not using for SharedPreferences
import android.content.Intent
import android.os.Bundle // For onCreate
import android.util.Log

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val WIDGET_METHOD_CHANNEL_NAME = "com.anexon.echolog/widget"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle intent if the app was launched by widget click
        intent?.let { handleWidgetIntent(it) }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_METHOD_CHANNEL_NAME).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "forceWidgetUpdate" -> {
                    Log.d("MainActivity", "Received 'forceWidgetUpdate' from Flutter. Triggering widget update.")
                    // Flutter's recording_service.dart (or similar) should have already called
                    // HomeWidget.saveWidgetData(...) before calling this method.
                    // This native call just tells the widget to re-render itself using that data.

                    val updateIntent = Intent(this, RecentRecordingWidget::class.java)
                    updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    
                    val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                    val componentName = ComponentName(applicationContext, RecentRecordingWidget::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                    
                    if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                        updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                        sendBroadcast(updateIntent)
                        Log.d("MainActivity", "Broadcast sent to update RecentRecordingWidget. IDs: ${appWidgetIds.joinToString()}")
                        result.success("Widget update broadcast sent successfully.")
                    } else {
                        Log.d("MainActivity", "No RecentRecordingWidget instances found to update.")
                        result.success("No widget instances found, so no update broadcast sent.")
                    }
                }
                "widgetLaunchedApp" -> { // Called by Flutter's main.dart if it detects a generic widget launch
                    val sourceDetails = call.argument<String>("sourceDetails")
                    Log.d("MainActivity", "Flutter informed MainActivity that app was launched from widget. Details: $sourceDetails")
                    result.success("Native MainActivity acknowledged app launch from widget via Flutter.")
                }
                // "openRecording" might still be called by Flutter if it processes the widget click first
                // and then decides to tell native. If widget directly calls onNewIntent, this might be less used.
                "openRecording" -> {
                     val recordingId = call.argument<String>("recordingId")
                     Log.d("MainActivity", "Received 'openRecording' for ID: $recordingId (likely from Flutter after widget interaction).")
                     result.success("Native MainActivity acknowledged 'openRecording' processing by Flutter for ID: $recordingId.")
                }
                else -> {
                    Log.w("MainActivity", "Unknown method call received on widget channel: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle intent if the app is already running and receives a new intent from widget click
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent) {
        // Check for the custom action defined in RecentRecordingWidget
        if (intent.action == RecentRecordingWidget.ACTION_OPEN_SPECIFIC_RECORDING) {
            val recordingId = intent.getStringExtra("recording_id_to_open")
            if (recordingId != null) {
                Log.d("MainActivity", "Intent to open specific recording ID: $recordingId from widget.")
                // Inform Flutter to navigate to the specific recording.
                // Ensure your Flutter app's main.dart handles "navigateToRecording" method call.
                flutterEngine?.dartExecutor?.binaryMessenger?.let {
                    MethodChannel(it, WIDGET_METHOD_CHANNEL_NAME).invokeMethod("navigateToRecording", recordingId)
                }
            } else {
                Log.d("MainActivity", "Widget launched app with specific action but no recording_id_to_open.")
            }
        } else {
            // Could be a generic launch or another action
            Log.d("MainActivity", "Received intent with action: ${intent.action}")
        }
    }
}