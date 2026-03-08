package com.copynote.memo_copypaste

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.widget.Toast
import java.io.File

class MemoWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_COPY -> {
                val text = intent.getStringExtra(EXTRA_TEXT) ?: return
                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("memo", text))
                Toast.makeText(context, "클립보드에 복사됨", Toast.LENGTH_SHORT).show()
            }
            ACTION_REFRESH -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS) ?: return
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    companion object {
        const val ACTION_COPY = "com.copynote.memo_copypaste.ACTION_COPY"
        const val ACTION_REFRESH = "com.copynote.memo_copypaste.ACTION_REFRESH"
        const val EXTRA_TEXT = "extra_text"

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_memo)

            // Set up list adapter
            val serviceIntent = Intent(context, MemoWidgetService::class.java)
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)

            // Set up copy click template
            val copyIntent = Intent(context, MemoWidget::class.java).apply {
                action = ACTION_COPY
            }
            val copyPendingIntent = PendingIntent.getBroadcast(
                context, 0, copyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_list, copyPendingIntent)

            // Open app button
            val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (openIntent != null) {
                val openPendingIntent = PendingIntent.getActivity(
                    context, 0, openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_add_btn, openPendingIntent)
            }

            // Refresh button
            val refreshIntent = Intent(context, MemoWidget::class.java).apply {
                action = ACTION_REFRESH
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context, appWidgetId, refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_btn, refreshPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
        }
    }
}

class MemoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MemoWidgetFactory(applicationContext)
    }
}

class MemoWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var snippets = mutableListOf<Pair<String, String>>() // title, content

    override fun onCreate() {}

    override fun onDataSetChanged() {
        snippets.clear()
        try {
            val dbPath = File(context.getDatabasePath("memo_copypaste.db").path)
            if (!dbPath.exists()) return
            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery(
                "SELECT title, content FROM snippets ORDER BY isPinned DESC, copyCount DESC LIMIT 20",
                null
            )
            while (cursor.moveToNext()) {
                val title = cursor.getString(0) ?: ""
                val content = cursor.getString(1) ?: ""
                snippets.add(Pair(title, content))
            }
            cursor.close()
            db.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        snippets.clear()
    }

    override fun getCount(): Int = snippets.size

    override fun getViewAt(position: Int): RemoteViews {
        val (title, content) = snippets[position]
        val views = RemoteViews(context.packageName, R.layout.widget_item)
        views.setTextViewText(R.id.item_title, title.ifEmpty { content.take(30) })
        views.setTextViewText(R.id.item_content, content)

        val fillInIntent = Intent().apply {
            putExtra(MemoWidget.EXTRA_TEXT, content)
        }
        views.setOnClickFillInIntent(R.id.item_root, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
}
