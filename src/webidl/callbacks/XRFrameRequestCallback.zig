//! WebIDL callback: XRFrameRequestCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const XRFrameRequestCallback = *const fn (time: anyopaque, frame: anyopaque) void;
