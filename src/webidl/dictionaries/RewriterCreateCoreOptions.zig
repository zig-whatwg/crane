//! WebIDL dictionary: RewriterCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const RewriterCreateCoreOptions = struct {
    tone: ?enums.RewriterTone = null,
    format: ?enums.RewriterFormat = null,
    length: ?enums.RewriterLength = null,
    expectedInputLanguages: ?[]const runtime.DOMString = null,
    expectedContextLanguages: ?[]const runtime.DOMString = null,
    outputLanguage: ?runtime.DOMString = null,
};
