//! WebIDL dictionary: SetHTMLOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const SanitizerConfig = @import("SanitizerConfig.zig").SanitizerConfig;

pub const SetHTMLOptions = struct {
    sanitizer: ?runtime.JSValue = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"sanitizer"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "sanitizer", .{ .string = "default" } },
    };
};
