//! WebIDL dictionary: MediaStreamTrackProcessorInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const MediaStreamTrackProcessorInit = struct {
    track: *runtime.Instance,
    maxBufferSize: ?u16 = null,
};
