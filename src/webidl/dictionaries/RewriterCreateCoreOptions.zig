//! WebIDL dictionary: RewriterCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const RewriterCreateCoreOptions = struct {
    tone: ?enums.RewriterTone = null,
    format: ?enums.RewriterFormat = null,
    length: ?enums.RewriterLength = null,
    expectedInputLanguages: ?[]const runtime.DOMString = null,
    expectedContextLanguages: ?[]const runtime.DOMString = null,
    outputLanguage: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "tone", .{ .string = "as-is" } },
        .{ "format", .{ .string = "as-is" } },
        .{ "length", .{ .string = "as-is" } },
    };
};
