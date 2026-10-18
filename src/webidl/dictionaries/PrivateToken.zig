//! WebIDL dictionary: PrivateToken
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const PrivateToken = struct {
    version: enums.TokenVersion,
    operation: enums.OperationType,
    refreshPolicy: ?enums.RefreshPolicy = null,
    issuers: ?[]const runtime.USVString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "refreshPolicy", .{ .string = "none" } },
    };
};
