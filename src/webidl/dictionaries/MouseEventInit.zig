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
    screenX: ?f64 = null,
    screenY: ?f64 = null,
    clientX: ?f64 = null,
    clientY: ?f64 = null,
    movementX: ?f64 = null,
    movementY: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "screenX", "screenY", "clientX", "clientY", "movementX", "movementY" };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"relatedTarget"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "relatedTarget", "EventTarget" },
    };
};
