//! WebIDL dictionary: UIEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const UIEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    view: ?*runtime.Instance = null,
    detail: ?i32 = null,
    sourceCapabilities: ?*runtime.Instance = null,
    which: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "view", .null },
        .{ "detail", .{ .number = 0 } },
        .{ "sourceCapabilities", .null },
        .{ "which", .{ .number = 0 } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "view", "sourceCapabilities" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "view", "Window" },
        .{ "sourceCapabilities", "InputDeviceCapabilities" },
    };
};
