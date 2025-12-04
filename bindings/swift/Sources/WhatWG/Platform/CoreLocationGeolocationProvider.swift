#if os(iOS) || os(macOS) || os(watchOS)
import Foundation
import CoreLocation

/// Geolocation provider implementation using CoreLocation.
///
/// This provider uses CLLocationManager for location services.
/// Make sure to add the appropriate usage description keys to your Info.plist:
/// - NSLocationWhenInUseUsageDescription
/// - NSLocationAlwaysUsageDescription (if needed)
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.geolocationProvider = CoreLocationGeolocationProvider()
/// ```
///
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public final class CoreLocationGeolocationProvider: NSObject, GeolocationProvider, @unchecked Sendable {
    
    private let locationManager: CLLocationManager
    private var watchCallbacks: [Int: @Sendable (Result<GeolocationPosition, GeolocationError>) -> Void] = [:]
    private var oneTimeCallbacks: [(options: PositionOptions, continuation: CheckedContinuation<GeolocationPosition, Error>)] = []
    private var nextWatchId: Int = 1
    private let lock = NSLock()
    
    /// Creates a new iOS geolocation provider.
    public override init() {
        self.locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
    }
    
    // MARK: - GeolocationProvider
    
    public func getCurrentPosition(options: PositionOptions) async throws -> GeolocationPosition {
        // Check authorization
        let status = locationManager.authorizationStatus
        if status == .denied || status == .restricted {
            throw GeolocationError.permissionDenied
        }
        
        // Request authorization if needed
        if status == .notDetermined {
            await MainActor.run {
                locationManager.requestWhenInUseAuthorization()
            }
        }
        
        // Set accuracy based on options
        await MainActor.run {
            locationManager.desiredAccuracy = options.enableHighAccuracy
                ? kCLLocationAccuracyBest
                : kCLLocationAccuracyHundredMeters
        }
        
        // Check for cached location if maximumAge allows
        if options.maximumAge > 0 {
            if let cachedLocation = locationManager.location {
                let age = Date().timeIntervalSince(cachedLocation.timestamp) * 1000
                if age <= Double(options.maximumAge) {
                    return cachedLocation.toGeolocationPosition()
                }
            }
        }
        
        // Request location update
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            oneTimeCallbacks.append((options: options, continuation: continuation))
            lock.unlock()
            
            DispatchQueue.main.async {
                self.locationManager.requestLocation()
            }
            
            // Set up timeout if specified
            if options.timeout != .max {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(options.timeout))) { [weak self] in
                    self?.handleTimeout(for: continuation)
                }
            }
        }
    }
    
    public func watchPosition(
        options: PositionOptions,
        callback: @escaping @Sendable (Result<GeolocationPosition, GeolocationError>) -> Void
    ) -> Int {
        lock.lock()
        let watchId = nextWatchId
        nextWatchId += 1
        watchCallbacks[watchId] = callback
        lock.unlock()
        
        // Configure and start location updates
        DispatchQueue.main.async {
            self.locationManager.desiredAccuracy = options.enableHighAccuracy
                ? kCLLocationAccuracyBest
                : kCLLocationAccuracyHundredMeters
            self.locationManager.startUpdatingLocation()
        }
        
        return watchId
    }
    
    public func clearWatch(watchId: Int) {
        lock.lock()
        watchCallbacks.removeValue(forKey: watchId)
        let hasRemainingWatches = !watchCallbacks.isEmpty
        lock.unlock()
        
        if !hasRemainingWatches {
            DispatchQueue.main.async {
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
    
    // MARK: - Private
    
    private func handleTimeout(for continuation: CheckedContinuation<GeolocationPosition, Error>) {
        lock.lock()
        if let index = oneTimeCallbacks.firstIndex(where: { $0.continuation == continuation as AnyObject }) {
            let callback = oneTimeCallbacks.remove(at: index)
            lock.unlock()
            callback.continuation.resume(throwing: GeolocationError.timeout)
        } else {
            lock.unlock()
        }
    }
}

// MARK: - CLLocationManagerDelegate

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension CoreLocationGeolocationProvider: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let position = location.toGeolocationPosition()
        
        // Handle one-time callbacks
        lock.lock()
        let callbacks = oneTimeCallbacks
        oneTimeCallbacks.removeAll()
        lock.unlock()
        
        for callback in callbacks {
            callback.continuation.resume(returning: position)
        }
        
        // Notify all watch callbacks
        lock.lock()
        let watches = watchCallbacks
        lock.unlock()
        
        for (_, callback) in watches {
            callback(.success(position))
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let geoError: GeolocationError
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                geoError = .permissionDenied
            case .locationUnknown:
                geoError = .positionUnavailable
            default:
                geoError = .positionUnavailable
            }
        } else {
            geoError = .positionUnavailable
        }
        
        // Handle one-time callbacks
        lock.lock()
        let callbacks = oneTimeCallbacks
        oneTimeCallbacks.removeAll()
        lock.unlock()
        
        for callback in callbacks {
            callback.continuation.resume(throwing: geoError)
        }
        
        // Notify all watch callbacks
        lock.lock()
        let watches = watchCallbacks
        lock.unlock()
        
        for (_, callback) in watches {
            callback(.failure(geoError))
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            // Cancel pending requests
            lock.lock()
            let callbacks = oneTimeCallbacks
            oneTimeCallbacks.removeAll()
            lock.unlock()
            
            for callback in callbacks {
                callback.continuation.resume(throwing: GeolocationError.permissionDenied)
            }
        }
    }
}

// MARK: - CLLocation Extension

extension CLLocation {
    func toGeolocationPosition() -> GeolocationPosition {
        let coords = GeolocationCoordinates(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            altitude: altitude,
            accuracy: horizontalAccuracy,
            altitudeAccuracy: verticalAccuracy,
            heading: course >= 0 ? course : nil,
            speed: speed >= 0 ? speed : nil
        )
        return GeolocationPosition(coords: coords, timestamp: timestamp)
    }
}

// MARK: - Backwards Compatibility

/// Deprecated: Use `CoreLocationGeolocationProvider` instead.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@available(*, deprecated, renamed: "CoreLocationGeolocationProvider")
public typealias iOSGeolocationProvider = CoreLocationGeolocationProvider
#endif
