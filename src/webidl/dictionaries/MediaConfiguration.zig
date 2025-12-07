//! WebIDL dictionary: MediaConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const VideoConfiguration = @import("VideoConfiguration.zig").VideoConfiguration;
const AudioConfiguration = @import("AudioConfiguration.zig").AudioConfiguration;

pub const MediaConfiguration = struct {
    video: ?VideoConfiguration = null,
    audio: ?AudioConfiguration = null,
};
