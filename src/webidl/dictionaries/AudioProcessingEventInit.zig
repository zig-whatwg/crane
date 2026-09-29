//! WebIDL dictionary: AudioProcessingEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const AudioProcessingEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    playbackTime: f64,
    inputBuffer: *runtime.Instance,
    outputBuffer: *runtime.Instance,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"playbackTime"};
};
