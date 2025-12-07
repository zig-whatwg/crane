//! WebIDL callback: VideoFrameRequestCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const VideoFrameRequestCallback = *const fn (now: *const anyopaque, metadata: *const anyopaque) void;
