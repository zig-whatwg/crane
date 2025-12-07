//! WebIDL dictionary: PerformanceMarkOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const PerformanceMarkOptions = struct {
    detail: ?v8.JSValue = null,
    startTime: ?typedefs.DOMHighResTimeStamp = null,
};
