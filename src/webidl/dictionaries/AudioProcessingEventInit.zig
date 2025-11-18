//! WebIDL dictionary: AudioProcessingEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const AudioProcessingEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    playbackTime: f64,
    inputBuffer: anyopaque,
    outputBuffer: anyopaque,
};
