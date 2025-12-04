package com.whatwg.android

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import com.whatwg.providers.ClipboardProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Android implementation of ClipboardProvider using ClipboardManager.
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * platform.clipboardProvider = AndroidClipboardProvider(context)
 * ```
 *
 * @param context Android context used to access ClipboardManager.
 */
class AndroidClipboardProvider(context: Context) : ClipboardProvider {
    
    private val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    
    override suspend fun readText(): String? = withContext(Dispatchers.Main) {
        val clip = clipboardManager.primaryClip ?: return@withContext null
        if (clip.itemCount > 0) {
            clip.getItemAt(0).text?.toString()
        } else {
            null
        }
    }
    
    override suspend fun writeText(text: String) = withContext(Dispatchers.Main) {
        val clip = ClipData.newPlainText("text", text)
        clipboardManager.setPrimaryClip(clip)
    }
    
    override suspend fun read(type: String): ByteArray? = withContext(Dispatchers.Main) {
        val clip = clipboardManager.primaryClip ?: return@withContext null
        if (clip.itemCount == 0) return@withContext null
        
        val item = clip.getItemAt(0)
        
        when (type) {
            "text/plain" -> item.text?.toString()?.toByteArray(Charsets.UTF_8)
            "text/html" -> item.htmlText?.toByteArray(Charsets.UTF_8)
            else -> {
                // Try to coerce to text for other types
                item.coerceToText(null)?.toString()?.toByteArray(Charsets.UTF_8)
            }
        }
    }
    
    override suspend fun write(data: ByteArray, type: String) = withContext(Dispatchers.Main) {
        when (type) {
            "text/plain" -> {
                val text = String(data, Charsets.UTF_8)
                val clip = ClipData.newPlainText("text", text)
                clipboardManager.setPrimaryClip(clip)
            }
            "text/html" -> {
                val html = String(data, Charsets.UTF_8)
                val clip = ClipData.newHtmlText("html", html, html)
                clipboardManager.setPrimaryClip(clip)
            }
            else -> throw UnsupportedOperationException("Unsupported clipboard type: $type")
        }
    }
    
    override fun canRead(): Boolean {
        return clipboardManager.hasPrimaryClip()
    }
    
    override fun canWrite(): Boolean = true
}
