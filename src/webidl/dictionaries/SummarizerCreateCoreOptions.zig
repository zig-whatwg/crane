//! WebIDL dictionary: SummarizerCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const SummarizerCreateCoreOptions = struct {
    type: ?enums.SummarizerType = null,
    format: ?enums.SummarizerFormat = null,
    length: ?enums.SummarizerLength = null,
    preference: ?enums.PerformancePreference = null,
    expectedInputLanguages: ?[]const runtime.DOMString = null,
    expectedContextLanguages: ?[]const runtime.DOMString = null,
    outputLanguage: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "type", .{ .string = "key-points" } },
        .{ "format", .{ .string = "markdown" } },
        .{ "length", .{ .string = "short" } },
        .{ "preference", .{ .string = "auto" } },
    };
};
