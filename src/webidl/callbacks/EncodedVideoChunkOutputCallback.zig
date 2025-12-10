//! WebIDL callback: EncodedVideoChunkOutputCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EncodedVideoChunkOutputCallback = *const fn (chunk: *runtime.Instance, metadata: runtime.JSValue) void;
