//! WebIDL dictionary: MemoryBreakdownEntry
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const MemoryAttribution = @import("MemoryAttribution.zig").MemoryAttribution;

pub const MemoryBreakdownEntry = struct {
    bytes: ?u64 = null,
    attribution: ?[]const MemoryAttribution = null,
    types: ?[]const runtime.DOMString = null,
};
