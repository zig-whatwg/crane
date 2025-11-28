//! WebIDL callback: FunctionStringCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const FunctionStringCallback = *const fn (data: runtime.DOMString) void;
