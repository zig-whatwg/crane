//! WebIDL dictionary: RTCStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const RTCStats = struct {
    timestamp: typedefs.DOMHighResTimeStamp,
    @"type": enums.RTCStatsType,
    id: runtime.DOMString,
};
