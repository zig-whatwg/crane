//! WebIDL callback: EncodedAudioChunkOutputCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const EncodedAudioChunkOutputCallback = *const fn (output: *const anyopaque, metadata: webidl.Opt(*const anyopaque)) void;
