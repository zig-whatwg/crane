//! WebIDL dictionary: GeolocationSensorReading
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
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

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "timestamp", "latitude", "longitude", "altitude", "accuracy", "altitudeAccuracy", "heading", "speed" };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "timestamp", "latitude", "longitude", "altitude", "accuracy", "altitudeAccuracy", "heading", "speed" };
};
