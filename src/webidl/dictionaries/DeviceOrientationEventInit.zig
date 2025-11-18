//! WebIDL dictionary: DeviceOrientationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const DeviceOrientationEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    alpha: ?anyopaque = null,
    beta: ?anyopaque = null,
    gamma: ?anyopaque = null,
    absolute: ?bool = null,
};
