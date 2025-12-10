//! WebIDL callback: PerformanceObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const PerformanceObserverCallback = *const fn (entries: runtime.JSValue, observer: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) void;
