//! WebIDL dictionary: AudioEncoderInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");

pub const AudioEncoderInit = struct {
    output: callbacks.EncodedAudioChunkOutputCallback,
    @"error": callbacks.WebCodecsErrorCallback,
};
