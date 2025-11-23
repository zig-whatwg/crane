//! WebIDL dictionary: GPUBindGroupLayoutEntry
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUBindGroupLayoutEntry = struct {
    binding: *const anyopaque,
    visibility: *const anyopaque,
    buffer: ?*const anyopaque = null,
    sampler: ?*const anyopaque = null,
    texture: ?*const anyopaque = null,
    storageTexture: ?*const anyopaque = null,
    externalTexture: ?*const anyopaque = null,
};
