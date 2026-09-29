//! WebIDL dictionary: MouseEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventModifierInit = @import("EventModifierInit.zig").EventModifierInit;

pub const MouseEventInit = struct {
    // Inherited from EventModifierInit
    base: EventModifierInit,

    button: ?i16 = null,
    buttons: ?u16 = null,
    relatedTarget: ?*runtime.Instance = null,
    movementX: ?f64 = null,
    movementY: ?f64 = null,
    screenX: ?f64 = null,
    screenY: ?f64 = null,
    clientX: ?f64 = null,
    clientY: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "movementX", "movementY", "screenX", "screenY", "clientX", "clientY" };
};
