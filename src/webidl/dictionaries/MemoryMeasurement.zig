//! WebIDL dictionary: MemoryMeasurement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MemoryBreakdownEntry = @import("MemoryBreakdownEntry.zig").MemoryBreakdownEntry;

pub const MemoryMeasurement = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    bytes: ?u64 = null,
    breakdown: ?[]const MemoryBreakdownEntry = null,
};
