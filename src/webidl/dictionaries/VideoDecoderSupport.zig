//! WebIDL dictionary: VideoDecoderSupport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const VideoDecoderConfig = @import("VideoDecoderConfig.zig").VideoDecoderConfig;

pub const VideoDecoderSupport = struct {
    supported: ?bool = null,
    config: ?VideoDecoderConfig = null,
};
