//! WebIDL dictionary: ImageDataSettings
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const ImageDataSettings = struct {
    colorSpace: ?enums.PredefinedColorSpace = null,
    pixelFormat: ?enums.ImageDataPixelFormat = null,
};
