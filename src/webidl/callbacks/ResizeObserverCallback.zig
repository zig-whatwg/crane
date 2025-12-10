//! WebIDL callback: ResizeObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const ResizeObserverCallback = *const fn (entries: runtime.JSValue, observer: runtime.JSValue) void;
