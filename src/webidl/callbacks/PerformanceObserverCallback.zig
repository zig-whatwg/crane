//! WebIDL callback: PerformanceObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PerformanceObserverCallback = *const fn (entries: *const anyopaque, observer: *const anyopaque, options: *const anyopaque) void;
