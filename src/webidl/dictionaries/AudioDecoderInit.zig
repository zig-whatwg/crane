//! WebIDL dictionary: AudioDecoderInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const AudioDecoderInit = struct {
    output: callbacks.AudioDataOutputCallback,
    @"error": callbacks.WebCodecsErrorCallback,
};
