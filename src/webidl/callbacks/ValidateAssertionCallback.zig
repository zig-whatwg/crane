//! WebIDL callback: ValidateAssertionCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const ValidateAssertionCallback = *const fn (assertion: runtime.DOMString, origin: runtime.DOMString) *const anyopaque;
