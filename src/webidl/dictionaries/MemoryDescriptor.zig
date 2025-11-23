//! WebIDL dictionary: MemoryDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MemoryDescriptor = struct {
    initial: *const anyopaque,
    maximum: ?*const anyopaque = null,
    address: ?*const anyopaque = null,
};
