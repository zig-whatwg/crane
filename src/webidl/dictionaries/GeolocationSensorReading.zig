//! WebIDL dictionary: GeolocationSensorReading
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const GeolocationSensorReading = struct {
    timestamp: ?typedefs.DOMHighResTimeStamp = null,
    latitude: ?f64 = null,
    longitude: ?f64 = null,
    altitude: ?f64 = null,
    accuracy: ?f64 = null,
    altitudeAccuracy: ?f64 = null,
    heading: ?f64 = null,
    speed: ?f64 = null,
};
