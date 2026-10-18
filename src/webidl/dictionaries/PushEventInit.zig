//! WebIDL dictionary: PushEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PushEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    data: ?typedefs.PushMessageDataInit = null,
    notification: ?*runtime.Instance = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "data", .null },
        .{ "notification", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "data", "notification" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "notification", "Notification" },
    };
};
