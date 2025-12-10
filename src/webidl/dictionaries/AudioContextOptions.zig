//! WebIDL dictionary: AudioContextOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const AudioSinkOptions = @import("AudioSinkOptions.zig").AudioSinkOptions;

pub const AudioContextOptions = struct {
    latencyHint: ?runtime.JSValue = null,
    sampleRate: ?f32 = null,
    sinkId: ?runtime.JSValue = null,
    renderSizeHint: ?runtime.JSValue = null,
};
