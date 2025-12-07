//! WebIDL callback: RTCSessionDescriptionCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const RTCSessionDescriptionCallback = *const fn (description: *const anyopaque) void;
