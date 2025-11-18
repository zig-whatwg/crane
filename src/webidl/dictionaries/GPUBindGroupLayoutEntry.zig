//! WebIDL dictionary: GPUBindGroupLayoutEntry
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUBindGroupLayoutEntry = struct {
    binding: anyopaque,
    visibility: anyopaque,
    buffer: ?anyopaque = null,
    sampler: ?anyopaque = null,
    texture: ?anyopaque = null,
    storageTexture: ?anyopaque = null,
    externalTexture: ?anyopaque = null,
};
