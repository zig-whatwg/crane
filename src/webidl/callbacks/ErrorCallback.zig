//! WebIDL callback: ErrorCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const ErrorCallback = *const fn (err: runtime.JSValue) void;
