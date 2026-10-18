//! WebIDL dictionary: WebTransportSendOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WebTransportSendOptions = struct {
    sendGroup: ?*runtime.Instance = null,
    sendOrder: ?i64 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "sendGroup", .null },
        .{ "sendOrder", .{ .number = 0 } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"sendGroup"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "sendGroup", "WebTransportSendGroup" },
    };
};
