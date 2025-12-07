//! WebIDL dictionary: WriterCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const WriterCreateCoreOptions = struct {
    tone: ?enums.WriterTone = null,
    format: ?enums.WriterFormat = null,
    length: ?enums.WriterLength = null,
    expectedInputLanguages: ?[]const runtime.DOMString = null,
    expectedContextLanguages: ?[]const runtime.DOMString = null,
    outputLanguage: ?runtime.DOMString = null,
};
