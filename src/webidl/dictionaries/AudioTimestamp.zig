//! WebIDL dictionary: AudioTimestamp
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const AudioTimestamp = struct {
    contextTime: ?f64 = null,
    performanceTime: ?typedefs.DOMHighResTimeStamp = null,
};
