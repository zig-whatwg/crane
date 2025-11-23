//! WebIDL dictionary: WriterCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WriterCreateCoreOptions = struct {
    tone: ?*const anyopaque = null,
    format: ?*const anyopaque = null,
    length: ?*const anyopaque = null,
    expectedInputLanguages: ?*const anyopaque = null,
    expectedContextLanguages: ?*const anyopaque = null,
    outputLanguage: ?runtime.DOMString = null,
};
