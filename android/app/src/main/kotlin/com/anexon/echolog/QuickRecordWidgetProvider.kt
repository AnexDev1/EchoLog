package com.anexon.echolog // Make sure this matches your actual package name

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build // <<--- THIS IMPORT IS CRUCIAL
import android.widget.RemoteViews
// import es.antonborri.home_widget.HomeWidgetPlugin // Only if you use its features

class QuickRecordWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_QUICK_RECORD = "com.anexon.echolog.ACTION_QUICK_RECORD"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.quick_record_widget_layout)

        // Create an Intent to launch MainActivity
        val launchIntent = Intent(context, MainActivity::class.java)
        launchIntent.action = ACTION_QUICK_RECORD

        // Line 40 where 'Build' is used:
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            launchIntent,
            pendingIntentFlags
        )

        views.setOnClickPendingIntent(R.id.quick_record_button, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }
}