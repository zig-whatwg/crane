//! WebIDL callback: OnErrorEventHandlerNonNull
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const OnErrorEventHandlerNonNull = *const fn (event: runtime.JSValue, source: runtime.DOMString, lineno: u32, colno: u32, @"error": runtime.JSValue) runtime.JSValue;
