//! WebIDL dictionary: SpeechSynthesisErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const SpeechSynthesisEventInit = @import("SpeechSynthesisEventInit.zig").SpeechSynthesisEventInit;

pub const SpeechSynthesisErrorEventInit = struct {
    // Inherited from SpeechSynthesisEventInit
    base: SpeechSynthesisEventInit,

    error: anyopaque,
};
