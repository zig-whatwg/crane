//! WebIDL dictionary: NotificationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const NotificationEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    notification: *runtime.Instance,
    action: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "action", .{ .string = "" } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "notification", "Notification" },
    };
};
