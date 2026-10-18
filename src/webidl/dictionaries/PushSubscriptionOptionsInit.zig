//! WebIDL dictionary: PushSubscriptionOptionsInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PushSubscriptionOptionsInit = struct {
    userVisibleOnly: ?bool = null,
    applicationServerKey: ?runtime.JSValue = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "userVisibleOnly", .{ .boolean = false } },
        .{ "applicationServerKey", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"applicationServerKey"};
};
