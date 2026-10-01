package com.example.sjmobile.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget kecil: hanya menampilkan streak. */
class StreakMiniWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        WidgetRenderer.renderMini(context, appWidgetManager, appWidgetIds, widgetData)
    }
}
