//! WebIDL enum: LanguageModelMessageType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const LanguageModelMessageType = enum {
    _text_,
    _image_,
    _audio_,
    _tool_call_,
    _tool_response_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "text", "image", "audio", "tool-call", "tool-response" };
};
