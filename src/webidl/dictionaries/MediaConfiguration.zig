//! WebIDL dictionary: MediaConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const VideoConfiguration = @import("VideoConfiguration.zig").VideoConfiguration;
const AudioConfiguration = @import("AudioConfiguration.zig").AudioConfiguration;

pub const MediaConfiguration = struct {
    video: ?VideoConfiguration = null,
    audio: ?AudioConfiguration = null,
};
