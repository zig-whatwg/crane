//! WebIDL dictionary: PopStateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const PopStateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    state: ?anyopaque = null,
    hasUAVisualTransition: ?bool = null,
};
