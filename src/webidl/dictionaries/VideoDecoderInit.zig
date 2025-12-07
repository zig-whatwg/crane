//! WebIDL dictionary: VideoDecoderInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const VideoDecoderInit = struct {
    output: callbacks.VideoFrameOutputCallback,
    @"error": callbacks.WebCodecsErrorCallback,
};
