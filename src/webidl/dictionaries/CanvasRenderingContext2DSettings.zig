//! WebIDL dictionary: CanvasRenderingContext2DSettings
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const CanvasRenderingContext2DSettings = struct {
    alpha: ?bool = null,
    desynchronized: ?bool = null,
    colorSpace: ?enums.PredefinedColorSpace = null,
    colorType: ?enums.CanvasColorType = null,
    willReadFrequently: ?bool = null,
};
