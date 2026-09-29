//! WebIDL dictionary: TouchInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const TouchInit = struct {
    identifier: i32,
    target: *runtime.Instance,
    clientX: ?f64 = null,
    clientY: ?f64 = null,
    screenX: ?f64 = null,
    screenY: ?f64 = null,
    pageX: ?f64 = null,
    pageY: ?f64 = null,
    radiusX: ?f32 = null,
    radiusY: ?f32 = null,
    rotationAngle: ?f32 = null,
    force: ?f32 = null,
    altitudeAngle: ?f64 = null,
    azimuthAngle: ?f64 = null,
    touchType: ?enums.TouchType = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "clientX", "clientY", "screenX", "screenY", "pageX", "pageY", "radiusX", "radiusY", "rotationAngle", "force", "altitudeAngle", "azimuthAngle" };
};
