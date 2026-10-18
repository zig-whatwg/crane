//! WebIDL dictionary: CacheQueryOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CacheQueryOptions = struct {
    ignoreSearch: ?bool = null,
    ignoreMethod: ?bool = null,
    ignoreVary: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "ignoreSearch", .{ .boolean = false } },
        .{ "ignoreMethod", .{ .boolean = false } },
        .{ "ignoreVary", .{ .boolean = false } },
    };
};
