//! WebIDL dictionary: WriterCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const WriterCreateCoreOptions = struct {
    tone: ?enums.WriterTone = null,
    format: ?enums.WriterFormat = null,
    length: ?enums.WriterLength = null,
    expectedInputLanguages: ?[]const runtime.DOMString = null,
    expectedContextLanguages: ?[]const runtime.DOMString = null,
    outputLanguage: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "tone", .{ .string = "neutral" } },
        .{ "format", .{ .string = "markdown" } },
        .{ "length", .{ .string = "short" } },
    };
};
