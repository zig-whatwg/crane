//! WebIDL dictionary: TouchEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventModifierInit = @import("EventModifierInit.zig").EventModifierInit;

pub const TouchEventInit = struct {
    // Inherited from EventModifierInit
    base: EventModifierInit,

    touches: ?[]const *runtime.Instance = null,
    targetTouches: ?[]const *runtime.Instance = null,
    changedTouches: ?[]const *runtime.Instance = null,
};
