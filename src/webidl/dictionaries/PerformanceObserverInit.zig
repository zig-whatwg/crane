//! WebIDL dictionary: PerformanceObserverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const PerformanceObserverInit = struct {
    entryTypes: ?[]const runtime.DOMString = null,
    @"type": ?runtime.DOMString = null,
    buffered: ?bool = null,
    durationThreshold: ?typedefs.DOMHighResTimeStamp = null,
};
