//! WebIDL dictionary: ProfilerSample
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ProfilerSample = struct {
    timestamp: anyopaque,
    stackId: ?u64 = null,
};
