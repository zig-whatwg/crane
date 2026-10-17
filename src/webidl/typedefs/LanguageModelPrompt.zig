//! WebIDL typedef: LanguageModelPrompt
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const LanguageModelPrompt = union(enum) {
    language_model_message_sequence: []const dictionaries.LanguageModelMessage,
    domstring: runtime.DOMString,
};
