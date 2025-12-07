//! WebIDL typedef: VibratePattern
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VibratePattern = union(enum) {
    ulong: u32,
    ulong_sequence: []const u32,
};
