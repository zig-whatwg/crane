//! WebIDL dictionary: PopStateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const PopStateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    state: ?v8.JSValue = null,
    hasUAVisualTransition: ?bool = null,
};
