//! WebIDL callback: PerformanceObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const PerformanceObserverCallback = *const fn (entries: *const anyopaque, observer: *const anyopaque, options: webidl.Opt(*const anyopaque)) void;
