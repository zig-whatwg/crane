//! WebIDL dictionary: LanguageModelMessage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const LanguageModelMessage = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    role: enums.LanguageModelMessageRole,
    content: typedefs.DOMStringOrSequenceOfLanguageModelMessageContent,
    prefix: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "prefix", .{ .boolean = false } },
    };
};
