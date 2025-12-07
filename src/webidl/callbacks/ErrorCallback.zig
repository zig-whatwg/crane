//! WebIDL callback: ErrorCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const ErrorCallback = *const fn (err: *const anyopaque) void;
