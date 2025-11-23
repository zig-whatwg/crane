//! WebIDL callback: EncodedAudioChunkOutputCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EncodedAudioChunkOutputCallback = *const fn (output: *const anyopaque, metadata: *const anyopaque) void;
