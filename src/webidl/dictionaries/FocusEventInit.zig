//! WebIDL dictionary: FocusEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const UIEventInit = @import("UIEventInit.zig").UIEventInit;

pub const FocusEventInit = struct {
    // Inherited from UIEventInit
    base: UIEventInit,

    relatedTarget: ?*runtime.Instance = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "relatedTarget", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"relatedTarget"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "relatedTarget", "EventTarget" },
    };
};
