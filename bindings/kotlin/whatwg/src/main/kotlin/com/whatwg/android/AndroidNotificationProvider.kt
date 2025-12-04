package com.whatwg.android

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.whatwg.providers.NotificationHandle
import com.whatwg.providers.NotificationOptions
import com.whatwg.providers.NotificationPermission
import com.whatwg.providers.NotificationProvider
import java.util.concurrent.atomic.AtomicInteger

/**
 * Android implementation of NotificationProvider using NotificationManager.
 *
 * Requires POST_NOTIFICATIONS permission on Android 13+ (API 33+).
 * Must create a notification channel before showing notifications on Android 8+ (API 26+).
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * platform.notificationProvider = AndroidNotificationProvider(context)
 * ```
 *
 * @param context Android context.
 * @param channelId The notification channel ID.
 * @param channelName The notification channel name.
 * @param smallIconRes Resource ID for the small notification icon.
 */
class AndroidNotificationProvider(
    private val context: Context,
    private val channelId: String = "whatwg_default",
    private val channelName: String = "Default",
    private val smallIconRes: Int = android.R.drawable.ic_dialog_info
) : NotificationProvider {
    
    private val notificationManager = NotificationManagerCompat.from(context)
    private val nextNotificationId = AtomicInteger(1)
    private val activeNotifications = mutableMapOf<String, AndroidNotificationHandle>()
    
    init {
        // Create notification channel for Android 8+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_DEFAULT
            )
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    override val permission: NotificationPermission
        get() {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                when (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)) {
                    PackageManager.PERMISSION_GRANTED -> NotificationPermission.GRANTED
                    else -> NotificationPermission.DENIED
                }
            } else {
                if (notificationManager.areNotificationsEnabled()) {
                    NotificationPermission.GRANTED
                } else {
                    NotificationPermission.DENIED
                }
            }
        }
    
    override suspend fun requestPermission(): NotificationPermission {
        // On Android, permission must be requested through the Activity
        // This is a simplified check - actual permission request needs UI
        return permission
    }
    
    override suspend fun show(options: NotificationOptions): NotificationHandle {
        if (permission != NotificationPermission.GRANTED) {
            throw SecurityException("Notification permission not granted")
        }
        
        val notificationId = options.tag?.hashCode() ?: nextNotificationId.getAndIncrement()
        
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(smallIconRes)
            .setContentTitle(options.title)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(!options.requireInteraction)
        
        options.body?.let { builder.setContentText(it) }
        
        if (options.silent) {
            builder.setSilent(true)
        }
        
        options.vibrate?.let { pattern ->
            builder.setVibrate(pattern.toLongArray())
        }
        
        // Add actions if provided
        options.actions.forEach { action ->
            val intent = Intent().apply {
                setAction("NOTIFICATION_ACTION_${action.action}")
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(0, action.title, pendingIntent)
        }
        
        notificationManager.notify(notificationId, builder.build())
        
        val handle = AndroidNotificationHandle(
            notificationId = notificationId,
            tag = options.tag,
            notificationManager = notificationManager
        )
        
        val tag = options.tag ?: notificationId.toString()
        activeNotifications[tag] = handle
        
        return handle
    }
}

/**
 * Handle to an active Android notification.
 */
class AndroidNotificationHandle(
    private val notificationId: Int,
    override val tag: String?,
    private val notificationManager: NotificationManagerCompat
) : NotificationHandle {
    
    override fun close() {
        notificationManager.cancel(notificationId)
    }
}
