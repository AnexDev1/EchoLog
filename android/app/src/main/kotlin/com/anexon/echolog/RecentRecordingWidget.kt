package com.anexon.echolog // Ensure this matches your package name

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin // For reading data

class RecentRecordingWidget : AppWidgetProvider() { // Renamed for consistency

    companion object {
        // Action for when the widget is clicked to open a specific recording
        const val ACTION_OPEN_SPECIFIC_RECORDING = "com.anexon.echolog.ACTION_OPEN_SPECIFIC_RECORDING"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("RecentRecordingWidget", "onUpdate called for IDs: ${appWidgetIds.joinToString()}")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    // Also handle direct broadcast if MainActivity sends it
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d("RecentRecordingWidget", "onReceive action: ${intent.action}")
        if (AppWidgetManager.ACTION_APPWIDGET_UPDATE == intent.action) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                Log.d("RecentRecordingWidget", "Handling ACTION_APPWIDGET_UPDATE in onReceive for IDs: ${appWidgetIds.joinToString()}")
                this.onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        Log.d("RecentRecordingWidget", "Updating widget ID: $appWidgetId")
        // Ensure your layout file is named recent_recording_widget_layout.xml
        // and contains R.id.widget_container, R.id.widget_recording_title, R.id.widget_recording_duration
        val views = RemoteViews(context.packageName, R.layout.recent_recording_widget_layout)

        val widgetData = HomeWidgetPlugin.getData(context)
        val hasRecording = widgetData.getBoolean("has_recent_recording", false)
        Log.d("RecentRecordingWidget", "Widget ID $appWidgetId - hasRecording: $hasRecording")

        if (hasRecording) {
            val title = widgetData.getString("recent_recording_title", "N/A")
            val duration = widgetData.getString("recent_recording_duration", "--:--")
            val recordingId = widgetData.getString("recent_recording_id", null)

            Log.d("RecentRecordingWidget", "Widget ID $appWidgetId - Title: $title, ID: $recordingId")

            views.setTextViewText(R.id.widget_recording_title, title ?: "N/A")
            views.setTextViewText(R.id.widget_recording_duration, "Duration: ${duration ?: "--:--"}")

            if (recordingId != null) {
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    action = ACTION_OPEN_SPECIFIC_RECORDING // Use the defined constant
                    putExtra("recording_id_to_open", recordingId) // Extra for MainActivity
                    // FLAG_ACTIVITY_CLEAR_TOP will clear the activities on top of MainActivity if it's already running.
                    // FLAG_ACTIVITY_NEW_TASK is needed if launching from a context without an existing task (like a widget).
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }

                val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                // Use recordingId's hash or appWidgetId to make request code unique per widget instance or content
                val requestCode = recordingId.hashCode() 
                val pendingIntent = PendingIntent.getActivity(context, requestCode, launchIntent, pendingIntentFlags)
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            } else {
                // No specific recording ID, make it just open the app
                setGenericAppLaunchIntent(context, views, appWidgetId)
            }
        } else {
            views.setTextViewText(R.id.widget_recording_title, "No recent recording")
            views.setTextViewText(R.id.widget_recording_duration, "")
            setGenericAppLaunchIntent(context, views, appWidgetId)
        }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun setGenericAppLaunchIntent(context: Context, views: RemoteViews, appWidgetId: Int) {
        val launchAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            // You can add a generic action if MainActivity needs to know it was launched generically
            // action = "com.anexon.echolog.ACTION_LAUNCH_APP_GENERIC"
        }
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        // Use a different request code for generic launch to avoid conflicts
        val genericLaunchRequestCode = appWidgetId + 1000 
        val pendingIntent = PendingIntent.getActivity(context, genericLaunchRequestCode, launchAppIntent, pendingIntentFlags)
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
    }
}