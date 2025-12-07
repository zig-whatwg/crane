//! WebIDL dictionary: MemoryMeasurement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MemoryBreakdownEntry = @import("MemoryBreakdownEntry.zig").MemoryBreakdownEntry;

pub const MemoryMeasurement = struct {
    bytes: ?u64 = null,
    breakdown: ?[]const MemoryBreakdownEntry = null,
};
