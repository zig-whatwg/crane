//! WebIDL dictionary: GPUBindGroupLayoutEntry
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const GPUTextureBindingLayout = @import("GPUTextureBindingLayout.zig").GPUTextureBindingLayout;
const GPUExternalTextureBindingLayout = @import("GPUExternalTextureBindingLayout.zig").GPUExternalTextureBindingLayout;
const GPUStorageTextureBindingLayout = @import("GPUStorageTextureBindingLayout.zig").GPUStorageTextureBindingLayout;
const GPUBufferBindingLayout = @import("GPUBufferBindingLayout.zig").GPUBufferBindingLayout;
const GPUSamplerBindingLayout = @import("GPUSamplerBindingLayout.zig").GPUSamplerBindingLayout;

pub const GPUBindGroupLayoutEntry = struct {
    binding: typedefs.GPUIndex32,
    visibility: typedefs.GPUShaderStageFlags,
    buffer: ?GPUBufferBindingLayout = null,
    sampler: ?GPUSamplerBindingLayout = null,
    texture: ?GPUTextureBindingLayout = null,
    storageTexture: ?GPUStorageTextureBindingLayout = null,
    externalTexture: ?GPUExternalTextureBindingLayout = null,
};
