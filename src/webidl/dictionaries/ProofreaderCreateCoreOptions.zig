//! WebIDL dictionary: ProofreaderCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ProofreaderCreateCoreOptions = struct {
    includeCorrectionTypes: ?bool = null,
    includeCorrectionExplanations: ?bool = null,
    expectedInputLanguages: ?[]const runtime.DOMString = null,
    correctionExplanationLanguage: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "includeCorrectionTypes", .{ .boolean = false } },
        .{ "includeCorrectionExplanations", .{ .boolean = false } },
    };
};
