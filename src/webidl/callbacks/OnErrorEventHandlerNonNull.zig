//! WebIDL callback: OnErrorEventHandlerNonNull
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const OnErrorEventHandlerNonNull = *const fn (event: anyopaque, source: runtime.DOMString, lineno: u32, colno: u32, error: anyopaque) anyopaque;
