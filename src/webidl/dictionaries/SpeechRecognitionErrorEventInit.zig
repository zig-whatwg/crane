//! WebIDL dictionary: SpeechRecognitionErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const SpeechRecognitionErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    error: anyopaque,
    message: ?runtime.DOMString = null,
};
