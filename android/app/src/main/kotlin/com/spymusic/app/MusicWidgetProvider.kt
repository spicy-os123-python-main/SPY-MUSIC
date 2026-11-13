package com.spymusic.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews

open class MusicWidgetProvider(private val layoutResId: Int) : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, layoutResId)

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Clicking the widget opens MainActivity
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val launchPendingIntent = PendingIntent.getActivity(context, 0, launchIntent, pendingFlags)
        try {
            views.setOnClickPendingIntent(R.id.widget_container, launchPendingIntent)
        } catch (_: Exception) {}

        // Media button receiver component
        val mediaReceiver = ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver")

        // Play / Pause toggle
        val playPauseIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = mediaReceiver
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        }
        val playPausePending = PendingIntent.getBroadcast(context, 101, playPauseIntent, pendingFlags)
        try {
            views.setOnClickPendingIntent(R.id.btn_play_pause, playPausePending)
        } catch (_: Exception) {}

        // Next
        val nextIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = mediaReceiver
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_NEXT))
        }
        val nextPending = PendingIntent.getBroadcast(context, 102, nextIntent, pendingFlags)
        try {
            views.setOnClickPendingIntent(R.id.btn_next, nextPending)
        } catch (_: Exception) {}

        // Previous
        val prevIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = mediaReceiver
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
        }
        val prevPending = PendingIntent.getBroadcast(context, 103, prevIntent, pendingFlags)
        try {
            views.setOnClickPendingIntent(R.id.btn_prev, prevPending)
        } catch (_: Exception) {}

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

class Widget1x1Provider : MusicWidgetProvider(R.layout.widget_1x1)
class Widget1x2Provider : MusicWidgetProvider(R.layout.widget_1x2)
class Widget1x3Provider : MusicWidgetProvider(R.layout.widget_1x3)
class Widget1x4Provider : MusicWidgetProvider(R.layout.widget_1x4)
class Widget2x2Provider : MusicWidgetProvider(R.layout.widget_2x2)
class Widget2x3Provider : MusicWidgetProvider(R.layout.widget_2x3)
class Widget2x4Provider : MusicWidgetProvider(R.layout.widget_2x4)
