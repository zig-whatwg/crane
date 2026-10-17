//! WebIDL dictionary: TouchEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventModifierInit = @import("EventModifierInit.zig").EventModifierInit;

pub const TouchEventInit = struct {
    // Inherited from EventModifierInit
    base: EventModifierInit,

    touches: ?[]const *runtime.Instance = null,
    targetTouches: ?[]const *runtime.Instance = null,
    changedTouches: ?[]const *runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "touches", "Touch" },
        .{ "targetTouches", "Touch" },
        .{ "changedTouches", "Touch" },
    };
};
