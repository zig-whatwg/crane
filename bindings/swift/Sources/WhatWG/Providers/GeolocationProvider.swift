import Foundation

/// Protocol for providing geolocation functionality.
///
/// Implement this protocol to provide location services support.
///
public protocol GeolocationProvider: AnyObject, Sendable {
    
    /// Gets the current position.
    ///
    /// - Parameter options: Position options.
    /// - Returns: The current position.
    /// - Throws: If location is unavailable or denied.
    func getCurrentPosition(options: PositionOptions) async throws -> GeolocationPosition
    
    /// Watches for position changes.
    ///
    /// - Parameters:
    ///   - options: Position options.
    ///   - callback: Called when position changes.
    /// - Returns: A watch ID for cancellation.
    func watchPosition(
        options: PositionOptions,
        callback: @escaping @Sendable (Result<GeolocationPosition, GeolocationError>) -> Void
    ) -> Int
    
    /// Clears a position watch.
    ///
    /// - Parameter watchId: The watch ID to clear.
    func clearWatch(watchId: Int)
}

/// Options for position requests.
public struct PositionOptions: Sendable {
    /// Whether to enable high accuracy mode.
    public var enableHighAccuracy: Bool
    
    /// Maximum age of cached position in milliseconds.
    public var maximumAge: UInt32
    
    /// Timeout in milliseconds.
    public var timeout: UInt32
    
    public init(
        enableHighAccuracy: Bool = false,
        maximumAge: UInt32 = 0,
        timeout: UInt32 = .max
    ) {
        self.enableHighAccuracy = enableHighAccuracy
        self.maximumAge = maximumAge
        self.timeout = timeout
    }
}

/// A geographic position.
public struct GeolocationPosition: Sendable {
    /// The coordinates.
    public var coords: GeolocationCoordinates
    
    /// The timestamp.
    public var timestamp: Date
    
    public init(coords: GeolocationCoordinates, timestamp: Date = Date()) {
        self.coords = coords
        self.timestamp = timestamp
    }
}

/// Geographic coordinates.
public struct GeolocationCoordinates: Sendable {
    /// Latitude in degrees.
    public var latitude: Double
    
    /// Longitude in degrees.
    public var longitude: Double
    
    /// Altitude in meters (optional).
    public var altitude: Double?
    
    /// Accuracy in meters.
    public var accuracy: Double
    
    /// Altitude accuracy in meters (optional).
    public var altitudeAccuracy: Double?
    
    /// Heading in degrees (optional).
    public var heading: Double?
    
    /// Speed in meters per second (optional).
    public var speed: Double?
    
    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        accuracy: Double,
        altitudeAccuracy: Double? = nil,
        heading: Double? = nil,
        speed: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.accuracy = accuracy
        self.altitudeAccuracy = altitudeAccuracy
        self.heading = heading
        self.speed = speed
    }
}

/// Geolocation errors.
public enum GeolocationError: Error, Sendable {
    case permissionDenied
    case positionUnavailable
    case timeout
}
