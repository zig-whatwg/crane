//! WebIDL callback: Function
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const Function = *const fn (arguments: []const runtime.JSValue) runtime.JSValue;
