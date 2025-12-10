//! WebIDL callback: VideoFrameRequestCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoFrameRequestCallback = *const fn (now: *runtime.Instance, metadata: runtime.JSValue) void;
