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
};
