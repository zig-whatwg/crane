//! WebIDL dictionary: SpeechSynthesisErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const SpeechSynthesisEventInit = @import("SpeechSynthesisEventInit.zig").SpeechSynthesisEventInit;

pub const SpeechSynthesisErrorEventInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from SpeechSynthesisEventInit
    base: SpeechSynthesisEventInit,

    @"error": enums.SpeechSynthesisErrorCode,
};
