//! WebIDL typedef: LanguageModelPrompt
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const LanguageModelPrompt = union(enum) {
    language_model_message_sequence: []const dictionaries.LanguageModelMessage,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "language_model_message_sequence", .kind = .sequence },
        .{ .field = "domstring", .kind = .string },
    };
};
