//! WebIDL dictionary: DeviceMotionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const DeviceMotionEventRotationRateInit = @import("DeviceMotionEventRotationRateInit.zig").DeviceMotionEventRotationRateInit;
const DeviceMotionEventAccelerationInit = @import("DeviceMotionEventAccelerationInit.zig").DeviceMotionEventAccelerationInit;
const EventInit = @import("EventInit.zig").EventInit;

pub const DeviceMotionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    acceleration: ?DeviceMotionEventAccelerationInit = null,
    accelerationIncludingGravity: ?DeviceMotionEventAccelerationInit = null,
    rotationRate: ?DeviceMotionEventRotationRateInit = null,
    interval: ?f64 = null,
};
