//! WebIDL dictionary: LanguageModelMessage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const LanguageModelMessageContent = @import("LanguageModelMessageContent.zig").LanguageModelMessageContent;

pub const LanguageModelMessage = struct {
    role: enums.LanguageModelMessageRole,
    content: runtime.JSValue,
    prefix: ?bool = null,
};
