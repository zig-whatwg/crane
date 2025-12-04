package com.whatwg.android

import android.os.Handler
import android.os.Looper
import com.whatwg.providers.TimerProvider
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/**
 * Android implementation of TimerProvider using Handler/Looper.
 *
 * This provider uses the main thread Handler for timer callbacks.
 * For background timers, use [AndroidTimerProvider.withLooper].
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * platform.timerProvider = AndroidTimerProvider()
 * ```
 */
class AndroidTimerProvider(
    private val handler: Handler = Handler(Looper.getMainLooper())
) : TimerProvider {
    
    private val nextId = AtomicLong(1)
    private val timeoutRunnables = ConcurrentHashMap<Long, Runnable>()
    private val intervalRunnables = ConcurrentHashMap<Long, Runnable>()
    
    companion object {
        /**
         * Creates a timer provider with a custom looper.
         *
         * @param looper The looper to use for timer callbacks.
         */
        fun withLooper(looper: Looper): AndroidTimerProvider {
            return AndroidTimerProvider(Handler(looper))
        }
    }
    
    override fun setTimeout(delayMs: Long, callback: () -> Unit): Long {
        val id = nextId.getAndIncrement()
        
        val runnable = Runnable {
            timeoutRunnables.remove(id)
            callback()
        }
        
        timeoutRunnables[id] = runnable
        handler.postDelayed(runnable, delayMs)
        
        return id
    }
    
    override fun setInterval(intervalMs: Long, callback: () -> Unit): Long {
        val id = nextId.getAndIncrement()
        
        val runnable = object : Runnable {
            override fun run() {
                if (intervalRunnables.containsKey(id)) {
                    callback()
                    handler.postDelayed(this, intervalMs)
                }
            }
        }
        
        intervalRunnables[id] = runnable
        handler.postDelayed(runnable, intervalMs)
        
        return id
    }
    
    override fun clearTimeout(id: Long) {
        timeoutRunnables.remove(id)?.let { runnable ->
            handler.removeCallbacks(runnable)
        }
    }
    
    override fun clearInterval(id: Long) {
        intervalRunnables.remove(id)?.let { runnable ->
            handler.removeCallbacks(runnable)
        }
    }
    
    /**
     * Clears all pending timers.
     */
    fun clearAll() {
        timeoutRunnables.keys.toList().forEach { clearTimeout(it) }
        intervalRunnables.keys.toList().forEach { clearInterval(it) }
    }
}
