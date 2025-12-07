//! WebIDL callback: EncodedVideoChunkOutputCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const EncodedVideoChunkOutputCallback = *const fn (chunk: *const anyopaque, metadata: webidl.Opt(*const anyopaque)) void;
