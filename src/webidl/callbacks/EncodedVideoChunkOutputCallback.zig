//! WebIDL callback: EncodedVideoChunkOutputCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const EncodedVideoChunkOutputCallback = *const fn (chunk: *const anyopaque, metadata: webidl.Opt(*const anyopaque)) void;
