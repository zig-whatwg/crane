//! WebIDL dictionary: QueuingStrategy
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");

pub const QueuingStrategy = struct {
    highWaterMark: ?f64 = null,
    size: ?callbacks.QueuingStrategySize = null,
};
