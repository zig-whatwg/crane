//! WebIDL dictionary: ClientQueryOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ClientQueryOptions = struct {
    includeUncontrolled: ?bool = null,
    type: ?enums.ClientType = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "includeUncontrolled", .{ .boolean = false } },
        .{ "type", .{ .string = "window" } },
    };
};
