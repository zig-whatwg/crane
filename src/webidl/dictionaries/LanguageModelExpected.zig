//! WebIDL dictionary: LanguageModelExpected
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const LanguageModelExpected = struct {
    type: enums.LanguageModelMessageType,
    languages: ?[]const runtime.DOMString = null,
};
