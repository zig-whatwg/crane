//! WebIDL dictionary: SpeechSynthesisEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const SpeechSynthesisEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    utterance: *runtime.Instance,
    charIndex: ?u32 = null,
    charLength: ?u32 = null,
    elapsedTime: ?f32 = null,
    name: ?runtime.DOMString = null,
};
