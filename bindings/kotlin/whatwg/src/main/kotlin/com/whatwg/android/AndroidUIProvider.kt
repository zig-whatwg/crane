package com.whatwg.android

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.EditText
import com.whatwg.providers.UIProvider
import com.whatwg.providers.WindowHandle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.lang.ref.WeakReference
import kotlin.coroutines.resume

/**
 * Android implementation of UIProvider using AlertDialog and Intent.
 *
 * Note: This provider requires an Activity context for showing dialogs.
 * Using an Application context will cause the dialogs to fail.
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * platform.uiProvider = AndroidUIProvider(activity)
 * ```
 *
 * @param activity Activity context for showing dialogs.
 */
class AndroidUIProvider(activity: Activity) : UIProvider {
    
    private val activityRef = WeakReference(activity)
    
    override suspend fun alert(message: String) = withContext(Dispatchers.Main) {
        suspendCancellableCoroutine { continuation ->
            val activity = activityRef.get()
            if (activity == null || activity.isFinishing) {
                continuation.resume(Unit)
                return@suspendCancellableCoroutine
            }
            
            AlertDialog.Builder(activity)
                .setMessage(message)
                .setPositiveButton("OK") { dialog, _ ->
                    dialog.dismiss()
                    continuation.resume(Unit)
                }
                .setOnCancelListener {
                    continuation.resume(Unit)
                }
                .show()
        }
    }
    
    override suspend fun confirm(message: String): Boolean = withContext(Dispatchers.Main) {
        suspendCancellableCoroutine { continuation ->
            val activity = activityRef.get()
            if (activity == null || activity.isFinishing) {
                continuation.resume(false)
                return@suspendCancellableCoroutine
            }
            
            AlertDialog.Builder(activity)
                .setMessage(message)
                .setPositiveButton("OK") { dialog, _ ->
                    dialog.dismiss()
                    continuation.resume(true)
                }
                .setNegativeButton("Cancel") { dialog, _ ->
                    dialog.dismiss()
                    continuation.resume(false)
                }
                .setOnCancelListener {
                    continuation.resume(false)
                }
                .show()
        }
    }
    
    override suspend fun prompt(message: String, defaultValue: String?): String? = withContext(Dispatchers.Main) {
        suspendCancellableCoroutine { continuation ->
            val activity = activityRef.get()
            if (activity == null || activity.isFinishing) {
                continuation.resume(null)
                return@suspendCancellableCoroutine
            }
            
            val editText = EditText(activity).apply {
                setText(defaultValue ?: "")
            }
            
            AlertDialog.Builder(activity)
                .setMessage(message)
                .setView(editText)
                .setPositiveButton("OK") { dialog, _ ->
                    dialog.dismiss()
                    continuation.resume(editText.text.toString())
                }
                .setNegativeButton("Cancel") { dialog, _ ->
                    dialog.dismiss()
                    continuation.resume(null)
                }
                .setOnCancelListener {
                    continuation.resume(null)
                }
                .show()
        }
    }
    
    override suspend fun open(url: String?, target: String?, features: String?): WindowHandle? = withContext(Dispatchers.Main) {
        val activity = activityRef.get() ?: return@withContext null
        
        if (url.isNullOrEmpty()) return@withContext null
        
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        
        try {
            activity.startActivity(intent)
            AndroidWindowHandle(url)
        } catch (e: Exception) {
            null
        }
    }
    
    override suspend fun print() = withContext(Dispatchers.Main) {
        // Android printing requires a PrintManager and document adapter
        // This is a no-op as it needs specific document context
    }
    
    override fun scrollTo(x: Double, y: Double) {
        // Needs reference to the scroll view being controlled
    }
    
    override fun scrollBy(x: Double, y: Double) {
        // Needs reference to the scroll view being controlled
    }
}

/**
 * Handle to a window opened via Intent.
 *
 * Note: Android doesn't provide fine-grained control over external activities.
 */
class AndroidWindowHandle(
    private val url: String
) : WindowHandle {
    
    override fun close() {
        // Cannot close external activities
    }
    
    override fun focus() {
        // Cannot programmatically focus external activities
    }
    
    override fun blur() {
        // Cannot programmatically blur external activities
    }
    
    override fun postMessage(message: Any, targetOrigin: String) {
        // Cross-app messaging not supported via Intent
    }
}
