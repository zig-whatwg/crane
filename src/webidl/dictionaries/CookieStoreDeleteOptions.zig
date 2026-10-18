//! WebIDL dictionary: CookieStoreDeleteOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CookieStoreDeleteOptions = struct {
    name: runtime.USVString,
    domain: ?runtime.USVString = null,
    path: ?runtime.USVString = null,
    partitioned: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "domain", .null },
        .{ "path", .{ .string = "/" } },
        .{ "partitioned", .{ .boolean = false } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"domain"};
};
