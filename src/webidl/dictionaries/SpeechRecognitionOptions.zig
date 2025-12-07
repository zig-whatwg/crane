//! WebIDL dictionary: SpeechRecognitionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const SpeechRecognitionOptions = struct {
    langs: []const runtime.DOMString,
    processLocally: ?bool = null,
};
