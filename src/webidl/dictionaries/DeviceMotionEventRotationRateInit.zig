//! WebIDL dictionary: DeviceMotionEventRotationRateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DeviceMotionEventRotationRateInit = struct {
    alpha: ?f64 = null,
    beta: ?f64 = null,
    gamma: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "alpha", "beta", "gamma" };
};
