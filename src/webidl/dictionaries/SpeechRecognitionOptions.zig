//! WebIDL dictionary: SpeechRecognitionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const SpeechRecognitionOptions = struct {
    langs: []const runtime.DOMString,
    processLocally: ?bool = null,
    quality: ?enums.SpeechRecognitionQuality = null,
};
