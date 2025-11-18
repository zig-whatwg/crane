//! WebIDL callback: ValidateAssertionCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ValidateAssertionCallback = *const fn (assertion: runtime.DOMString, origin: runtime.DOMString) anyopaque;
