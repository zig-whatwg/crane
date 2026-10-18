//! WebIDL dictionary: KeyboardEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventModifierInit = @import("EventModifierInit.zig").EventModifierInit;

pub const KeyboardEventInit = struct {
    // Inherited from EventModifierInit
    base: EventModifierInit,

    key: ?runtime.DOMString = null,
    code: ?runtime.DOMString = null,
    location: ?u32 = null,
    repeat: ?bool = null,
    isComposing: ?bool = null,
    charCode: ?u32 = null,
    keyCode: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "key", .{ .string = "" } },
        .{ "code", .{ .string = "" } },
        .{ "location", .{ .number = 0 } },
        .{ "repeat", .{ .boolean = false } },
        .{ "isComposing", .{ .boolean = false } },
        .{ "charCode", .{ .number = 0 } },
        .{ "keyCode", .{ .number = 0 } },
    };
};
