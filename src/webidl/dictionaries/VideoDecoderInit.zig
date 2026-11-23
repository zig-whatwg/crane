//! WebIDL dictionary: VideoDecoderInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const VideoDecoderInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    output: callbacks.VideoFrameOutputCallback,
    @"error": callbacks.WebCodecsErrorCallback,
};
