//! WebIDL dictionary: GeolocationSensorReading
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GeolocationSensorReading = struct {
    timestamp: ?anyopaque = null,
    latitude: ?f64 = null,
    longitude: ?f64 = null,
    altitude: ?f64 = null,
    accuracy: ?f64 = null,
    altitudeAccuracy: ?f64 = null,
    heading: ?f64 = null,
    speed: ?f64 = null,
};
