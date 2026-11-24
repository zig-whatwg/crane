//! WebIDL typedef: DOMStringOrSequenceOfLanguageModelMessageContent
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const DOMStringOrSequenceOfLanguageModelMessageContent = union(enum) {
    domstring: runtime.DOMString,
    language_model_message_content_sequence: []const dictionaries.LanguageModelMessageContent,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "language_model_message_content_sequence", .kind = .{ .sequence = null } },
    };
};
