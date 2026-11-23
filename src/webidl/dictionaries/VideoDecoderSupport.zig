//! WebIDL dictionary: VideoDecoderSupport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const VideoDecoderConfig = @import("VideoDecoderConfig.zig").VideoDecoderConfig;

pub const VideoDecoderSupport = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    supported: ?bool = null,
    config: ?VideoDecoderConfig = null,
};
