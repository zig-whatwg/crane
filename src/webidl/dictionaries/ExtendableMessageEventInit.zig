//! WebIDL dictionary: ExtendableMessageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const ExtendableMessageEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    data: ?runtime.JSValue = null,
    origin: ?runtime.USVString = null,
    lastEventId: ?runtime.DOMString = null,
    source: ?runtime.JSValue = null,
    ports: ?[]const *runtime.Instance = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"data"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "data", .null },
        .{ "origin", .{ .string = "" } },
        .{ "lastEventId", .{ .string = "" } },
        .{ "source", .null },
        .{ "ports", .empty_sequence },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"source"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "ports", "MessagePort" },
    };
};
