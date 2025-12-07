//! WebIDL callback: Function
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const Function = *const fn (arguments: []const v8.JSValue) v8.JSValue;
