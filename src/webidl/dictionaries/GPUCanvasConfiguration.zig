//! WebIDL dictionary: GPUCanvasConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUCanvasToneMapping = @import("GPUCanvasToneMapping.zig").GPUCanvasToneMapping;

pub const GPUCanvasConfiguration = struct {
    device: *runtime.Instance,
    format: enums.GPUTextureFormat,
    usage: ?typedefs.GPUTextureUsageFlags = null,
    viewFormats: ?[]const enums.GPUTextureFormat = null,
    colorSpace: ?enums.PredefinedColorSpace = null,
    toneMapping: ?GPUCanvasToneMapping = null,
    alphaMode: ?enums.GPUCanvasAlphaMode = null,
};
