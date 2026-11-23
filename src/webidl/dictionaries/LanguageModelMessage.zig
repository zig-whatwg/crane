//! WebIDL dictionary: LanguageModelMessage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const LanguageModelMessageContent = @import("LanguageModelMessageContent.zig").LanguageModelMessageContent;

pub const LanguageModelMessage = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    role: enums.LanguageModelMessageRole,
    content: runtime.JSValue,
    prefix: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "prefix", .{ .boolean = false } },
    };
};
