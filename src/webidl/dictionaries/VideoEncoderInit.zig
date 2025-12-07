//! WebIDL dictionary: VideoEncoderInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");

pub const VideoEncoderInit = struct {
    output: callbacks.EncodedVideoChunkOutputCallback,
    @"error": callbacks.WebCodecsErrorCallback,
};
