//! WebIDL dictionary: ProfilerSample
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ProfilerSample = struct {
    timestamp: typedefs.DOMHighResTimeStamp,
    stackId: ?u64 = null,
};
