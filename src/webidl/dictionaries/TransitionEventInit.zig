//! WebIDL dictionary: TransitionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const TransitionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    propertyName: ?anyopaque = null,
    elapsedTime: ?f64 = null,
    pseudoElement: ?anyopaque = null,
};
