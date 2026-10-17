//! WebIDL dictionary: XRGPUProjectionLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const XRGPUProjectionLayerInit = struct {
    colorFormat: enums.GPUTextureFormat,
    depthStencilFormat: ?enums.GPUTextureFormat = null,
    textureUsage: ?typedefs.GPUTextureUsageFlags = null,
    scaleFactor: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"scaleFactor"};

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"depthStencilFormat"};
};
