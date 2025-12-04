package com.whatwg.android

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import com.whatwg.providers.GeolocationCoordinates
import com.whatwg.providers.GeolocationException
import com.whatwg.providers.GeolocationPosition
import com.whatwg.providers.GeolocationProvider
import com.whatwg.providers.PositionOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Android implementation of GeolocationProvider using LocationManager.
 *
 * Requires location permissions in AndroidManifest.xml:
 * - ACCESS_FINE_LOCATION (for high accuracy)
 * - ACCESS_COARSE_LOCATION (for approximate location)
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * platform.geolocationProvider = AndroidGeolocationProvider(context)
 * ```
 *
 * @param context Android context used to access LocationManager.
 */
class AndroidGeolocationProvider(context: Context) : GeolocationProvider {
    
    private val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val nextWatchId = AtomicInteger(1)
    private val watchListeners = ConcurrentHashMap<Int, LocationListener>()
    
    @SuppressLint("MissingPermission")
    override suspend fun getCurrentPosition(options: PositionOptions): GeolocationPosition =
        suspendCancellableCoroutine { continuation ->
            // Check if location is enabled
            val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            
            if (!isGpsEnabled && !isNetworkEnabled) {
                continuation.resumeWithException(GeolocationException.PositionUnavailable())
                return@suspendCancellableCoroutine
            }
            
            // Try to get cached location first if maximumAge allows
            if (options.maximumAge > 0) {
                val cachedLocation = getCachedLocation(options.enableHighAccuracy)
                if (cachedLocation != null) {
                    val age = System.currentTimeMillis() - cachedLocation.time
                    if (age <= options.maximumAge) {
                        continuation.resume(cachedLocation.toGeolocationPosition())
                        return@suspendCancellableCoroutine
                    }
                }
            }
            
            // Set up timeout
            val timeoutRunnable = if (options.timeout != Long.MAX_VALUE) {
                Runnable {
                    continuation.resumeWithException(GeolocationException.Timeout())
                }
            } else null
            
            val handler = android.os.Handler(Looper.getMainLooper())
            timeoutRunnable?.let { handler.postDelayed(it, options.timeout) }
            
            // Create location listener
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    timeoutRunnable?.let { handler.removeCallbacks(it) }
                    locationManager.removeUpdates(this)
                    continuation.resume(location.toGeolocationPosition())
                }
                
                override fun onProviderDisabled(provider: String) {
                    timeoutRunnable?.let { handler.removeCallbacks(it) }
                    locationManager.removeUpdates(this)
                    continuation.resumeWithException(GeolocationException.PositionUnavailable())
                }
                
                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
            }
            
            // Request location updates
            val provider = if (options.enableHighAccuracy && isGpsEnabled) {
                LocationManager.GPS_PROVIDER
            } else if (isNetworkEnabled) {
                LocationManager.NETWORK_PROVIDER
            } else {
                LocationManager.GPS_PROVIDER
            }
            
            try {
                locationManager.requestLocationUpdates(
                    provider,
                    0L,
                    0f,
                    listener,
                    Looper.getMainLooper()
                )
            } catch (e: SecurityException) {
                continuation.resumeWithException(GeolocationException.PermissionDenied())
                return@suspendCancellableCoroutine
            }
            
            continuation.invokeOnCancellation {
                timeoutRunnable?.let { handler.removeCallbacks(it) }
                locationManager.removeUpdates(listener)
            }
        }
    
    @SuppressLint("MissingPermission")
    override fun watchPosition(
        options: PositionOptions,
        callback: (Result<GeolocationPosition>) -> Unit
    ): Int {
        val watchId = nextWatchId.getAndIncrement()
        
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                callback(Result.success(location.toGeolocationPosition()))
            }
            
            override fun onProviderDisabled(provider: String) {
                callback(Result.failure(GeolocationException.PositionUnavailable()))
            }
            
            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
        }
        
        watchListeners[watchId] = listener
        
        val provider = if (options.enableHighAccuracy) {
            LocationManager.GPS_PROVIDER
        } else {
            LocationManager.NETWORK_PROVIDER
        }
        
        try {
            locationManager.requestLocationUpdates(
                provider,
                1000L, // Update every second
                1f,    // Update every meter
                listener,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            callback(Result.failure(GeolocationException.PermissionDenied()))
            watchListeners.remove(watchId)
        }
        
        return watchId
    }
    
    override fun clearWatch(watchId: Int) {
        watchListeners.remove(watchId)?.let { listener ->
            locationManager.removeUpdates(listener)
        }
    }
    
    @SuppressLint("MissingPermission")
    private fun getCachedLocation(highAccuracy: Boolean): Location? {
        return try {
            if (highAccuracy) {
                locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            } else {
                locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                    ?: locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            }
        } catch (e: SecurityException) {
            null
        }
    }
    
    private fun Location.toGeolocationPosition(): GeolocationPosition {
        return GeolocationPosition(
            coords = GeolocationCoordinates(
                latitude = latitude,
                longitude = longitude,
                altitude = if (hasAltitude()) altitude else null,
                accuracy = accuracy.toDouble(),
                altitudeAccuracy = if (hasVerticalAccuracy()) verticalAccuracyMeters.toDouble() else null,
                heading = if (hasBearing()) bearing.toDouble() else null,
                speed = if (hasSpeed()) speed.toDouble() else null
            ),
            timestamp = time
        )
    }
}
