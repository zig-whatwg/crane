//! WebIDL callback: XRFrameRequestCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const XRFrameRequestCallback = *const fn (time: *const anyopaque, frame: *const anyopaque) void;
