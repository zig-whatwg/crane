//! WebIDL dictionary: VideoEncoderSupport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const VideoEncoderConfig = @import("VideoEncoderConfig.zig").VideoEncoderConfig;

pub const VideoEncoderSupport = struct {
    supported: ?bool = null,
    config: ?VideoEncoderConfig = null,
};
