//! WebIDL dictionary: MemoryDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MemoryDescriptor = struct {
    initial: anyopaque,
    maximum: ?anyopaque = null,
    address: ?anyopaque = null,
};
