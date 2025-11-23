//! WebIDL dictionary: TouchEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventModifierInit = @import("EventModifierInit.zig").EventModifierInit;

pub const TouchEventInit = struct {
    // Inherited from EventModifierInit
    base: EventModifierInit,

    touches: ?*const anyopaque = null,
    targetTouches: ?*const anyopaque = null,
    changedTouches: ?*const anyopaque = null,
};
