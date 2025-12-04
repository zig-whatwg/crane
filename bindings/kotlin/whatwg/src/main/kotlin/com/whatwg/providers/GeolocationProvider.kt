package com.whatwg.providers

/**
 * Interface for providing geolocation functionality.
 *
 * Implement this interface to provide location services support.
 */
interface GeolocationProvider {

    /**
     * Gets the current position.
     *
     * @param options Position options.
     * @return The current position.
     * @throws GeolocationException If location is unavailable or denied.
     */
    suspend fun getCurrentPosition(options: PositionOptions = PositionOptions()): GeolocationPosition

    /**
     * Watches for position changes.
     *
     * @param options Position options.
     * @param callback Called when position changes.
     * @return A watch ID for cancellation.
     */
    fun watchPosition(
        options: PositionOptions = PositionOptions(),
        callback: (Result<GeolocationPosition>) -> Unit
    ): Int

    /**
     * Clears a position watch.
     *
     * @param watchId The watch ID to clear.
     */
    fun clearWatch(watchId: Int)
}

/**
 * Options for position requests.
 */
data class PositionOptions(
    /**
     * Whether to enable high accuracy mode.
     */
    val enableHighAccuracy: Boolean = false,
    
    /**
     * Maximum age of cached position in milliseconds.
     */
    val maximumAge: Long = 0,
    
    /**
     * Timeout in milliseconds.
     */
    val timeout: Long = Long.MAX_VALUE
)

/**
 * A geographic position.
 */
data class GeolocationPosition(
    /**
     * The coordinates.
     */
    val coords: GeolocationCoordinates,
    
    /**
     * The timestamp in milliseconds.
     */
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Geographic coordinates.
 */
data class GeolocationCoordinates(
    /**
     * Latitude in degrees.
     */
    val latitude: Double,
    
    /**
     * Longitude in degrees.
     */
    val longitude: Double,
    
    /**
     * Altitude in meters (optional).
     */
    val altitude: Double? = null,
    
    /**
     * Accuracy in meters.
     */
    val accuracy: Double,
    
    /**
     * Altitude accuracy in meters (optional).
     */
    val altitudeAccuracy: Double? = null,
    
    /**
     * Heading in degrees (optional).
     */
    val heading: Double? = null,
    
    /**
     * Speed in meters per second (optional).
     */
    val speed: Double? = null
)

/**
 * Geolocation errors.
 */
sealed class GeolocationException(message: String) : Exception(message) {
    class PermissionDenied : GeolocationException("Location permission denied")
    class PositionUnavailable : GeolocationException("Position unavailable")
    class Timeout : GeolocationException("Location request timed out")
}
