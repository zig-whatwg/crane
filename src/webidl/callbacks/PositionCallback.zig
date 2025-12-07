//! WebIDL callback: PositionCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const PositionCallback = *const fn (position: *const anyopaque) void;
