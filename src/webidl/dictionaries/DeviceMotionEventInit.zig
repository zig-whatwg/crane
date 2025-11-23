//! WebIDL dictionary: DeviceMotionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const DeviceMotionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    acceleration: ?*const anyopaque = null,
    accelerationIncludingGravity: ?*const anyopaque = null,
    rotationRate: ?*const anyopaque = null,
    interval: ?f64 = null,
};
