//! WebIDL callback: PerformanceObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PerformanceObserverCallback = *const fn (entries: *runtime.Instance, observer: *runtime.Instance, options: runtime.JSValue) void;
