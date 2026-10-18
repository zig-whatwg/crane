//! WebIDL dictionary: CookieInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const CookieInit = struct {
    name: runtime.USVString,
    value: runtime.USVString,
    expires: ?typedefs.DOMHighResTimeStamp = null,
    domain: ?runtime.USVString = null,
    path: ?runtime.USVString = null,
    sameSite: ?enums.CookieSameSite = null,
    partitioned: ?bool = null,
    maxAge: ?i64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"expires"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "expires", .null },
        .{ "domain", .null },
        .{ "path", .{ .string = "/" } },
        .{ "sameSite", .{ .string = "strict" } },
        .{ "partitioned", .{ .boolean = false } },
        .{ "maxAge", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "expires", "domain", "maxAge" };
};
