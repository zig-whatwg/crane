//! WebIDL dictionary: LanguageModelExpected
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const LanguageModelExpected = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    type: enums.LanguageModelMessageType,
    languages: ?[]const runtime.DOMString = null,
};
