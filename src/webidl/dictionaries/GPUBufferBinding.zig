//! WebIDL dictionary: GPUBufferBinding
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUBufferBinding = struct {
    buffer: *const anyopaque,
    offset: ?*const anyopaque = null,
    size: ?*const anyopaque = null,
};
