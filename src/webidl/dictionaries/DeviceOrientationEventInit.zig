//! WebIDL dictionary: DeviceOrientationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const DeviceOrientationEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    alpha: ?f64 = null,
    beta: ?f64 = null,
    gamma: ?f64 = null,
    absolute: ?bool = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "alpha", "beta", "gamma" };
};
