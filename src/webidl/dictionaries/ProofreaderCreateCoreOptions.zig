//! WebIDL dictionary: ProofreaderCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ProofreaderCreateCoreOptions = struct {
    includeCorrectionTypes: ?bool = null,
    includeCorrectionExplanations: ?bool = null,
    expectedInputLanguages: ?[]const runtime.DOMString = null,
    correctionExplanationLanguage: ?runtime.DOMString = null,
};
