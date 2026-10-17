//! WebIDL dictionary: XRGPULayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const XRGPULayerInit = struct {
    colorFormat: enums.GPUTextureFormat,
    depthStencilFormat: ?enums.GPUTextureFormat = null,
    textureUsage: ?typedefs.GPUTextureUsageFlags = null,
    space: *runtime.Instance,
    mipLevels: ?u32 = null,
    viewPixelWidth: u32,
    viewPixelHeight: u32,
    layout: ?enums.XRLayerLayout = null,
    isStatic: ?bool = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"depthStencilFormat"};
};
