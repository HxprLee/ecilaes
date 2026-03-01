package com.example.music_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import com.ryanheise.audioservice.MediaButtonReceiver
import androidx.palette.graphics.Palette
import android.graphics.LinearGradient
import android.graphics.Shader

class MusicWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.music_widget).apply {
                // Set text
                val title = widgetData.getString("title", "Not Playing")
                val artist = widgetData.getString("artist", "-")
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_artist, artist)

                // Set images
                val artPath = widgetData.getString("artPath", null)
                if (artPath != null) {
                    val file = File(artPath)
                    if (file.exists()) {
                        val options = BitmapFactory.Options().apply {
                            inSampleSize = 2 // Resample to avoid OOM or transaction limit issues
                        }
                        val bitmap = BitmapFactory.decodeFile(file.absolutePath, options)
                        if (bitmap != null) {
                            // Mini Art (Rounded in Software)
                            val rounded = getRoundedCornerBitmap(bitmap, 40) // ~8dp equivalent at 2x/3x
                            setImageViewBitmap(R.id.widget_art_mini, rounded)
                            
                            // Extract colors using Palette
                            val palette = Palette.from(bitmap).generate()
                            val vibrant = palette.getVibrantColor(0xFF333333.toInt())
                            val muted = palette.getMutedColor(0xFF111111.toInt())
                            
                            // Create Gradient Background
                            val gradientBitmap = createGradientBitmap(vibrant, muted, 400, 200)
                            setImageViewBitmap(R.id.widget_art_blur, gradientBitmap)
                        }
                    }
                } else {
                    setImageViewResource(R.id.widget_art_mini, 0)
                    setImageViewResource(R.id.widget_art_blur, R.drawable.widget_background)
                }

                // Set play/pause icon
                val isPlaying = widgetData.getBoolean("isPlaying", false)
                setImageViewResource(
                    R.id.widget_play_pause,
                    if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
                )

                // Pending Intents for controls
                setOnClickPendingIntent(R.id.widget_play_pause, createMediaButtonPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                
                // Open App Intent
                val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (openAppIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context, 0, openAppIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun createMediaButtonPendingIntent(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(context, MediaButtonReceiver::class.java).apply {
            action = Intent.ACTION_MEDIA_BUTTON
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        return PendingIntent.getBroadcast(
            context,
            keyCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun createGradientBitmap(startColor: Int, endColor: Int, width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint()
        
        val shader = LinearGradient(
            0f, 0f, width.toFloat(), height.toFloat(),
            startColor, endColor, Shader.TileMode.CLAMP
        )
        
        paint.shader = shader
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        
        return bitmap
    }

    private fun getRoundedCornerBitmap(bitmap: Bitmap, pixels: Int): Bitmap {
        val output = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val color = -0xbdbdbe
        val paint = Paint()
        val rect = Rect(0, 0, bitmap.width, bitmap.height)
        val rectF = RectF(rect)
        val roundPx = pixels.toFloat()

        paint.isAntiAlias = true
        canvas.drawARGB(0, 0, 0, 0)
        paint.color = color
        canvas.drawRoundRect(rectF, roundPx, roundPx, paint)

        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(bitmap, rect, rect, paint)

        return output
    }
}
