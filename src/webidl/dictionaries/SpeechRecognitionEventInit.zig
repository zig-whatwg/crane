//! WebIDL dictionary: SpeechRecognitionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const SpeechRecognitionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    resultIndex: ?u32 = null,
    results: *runtime.Instance,
};
