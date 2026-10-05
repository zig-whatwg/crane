//! WebIDL enum: SpeechSynthesisErrorCode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const SpeechSynthesisErrorCode = enum {
    _canceled_,
    _interrupted_,
    _audio_busy_,
    _audio_hardware_,
    _network_,
    _synthesis_unavailable_,
    _synthesis_failed_,
    _language_unavailable_,
    _voice_unavailable_,
    _text_too_long_,
    _invalid_argument_,
    _not_allowed_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "canceled", "interrupted", "audio-busy", "audio-hardware", "network", "synthesis-unavailable", "synthesis-failed", "language-unavailable", "voice-unavailable", "text-too-long", "invalid-argument", "not-allowed" };
};
