//! WebIDL dictionary: VideoEncoderSupport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const VideoEncoderConfig = @import("VideoEncoderConfig.zig").VideoEncoderConfig;

pub const VideoEncoderSupport = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    supported: ?bool = null,
    config: ?VideoEncoderConfig = null,
};
