//! WebIDL dictionary: ToolAnnotations
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ToolAnnotations = struct {
    readOnlyHint: ?bool = null,
    untrustedContentHint: ?bool = null,
    consequentialHint: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "readOnlyHint", .{ .boolean = false } },
        .{ "untrustedContentHint", .{ .boolean = false } },
        .{ "consequentialHint", .{ .boolean = false } },
    };
};
