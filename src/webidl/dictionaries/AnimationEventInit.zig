//! WebIDL dictionary: AnimationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const AnimationEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    animationName: ?*const anyopaque = null,
    elapsedTime: ?f64 = null,
    pseudoElement: ?*const anyopaque = null,
};
