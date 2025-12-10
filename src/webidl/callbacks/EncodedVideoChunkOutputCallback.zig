//! WebIDL callback: EncodedVideoChunkOutputCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const EncodedVideoChunkOutputCallback = *const fn (chunk: runtime.JSValue, metadata: webidl.Opt(runtime.JSValue)) void;
