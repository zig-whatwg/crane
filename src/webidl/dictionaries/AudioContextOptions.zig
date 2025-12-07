//! WebIDL dictionary: AudioContextOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const AudioSinkOptions = @import("AudioSinkOptions.zig").AudioSinkOptions;

pub const AudioContextOptions = struct {
    latencyHint: ?*const anyopaque = null,
    sampleRate: ?f32 = null,
    sinkId: ?*const anyopaque = null,
    renderSizeHint: ?*const anyopaque = null,
};
