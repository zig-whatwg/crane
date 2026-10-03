//! WebIDL dictionary: ImageBitmapOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ImageBitmapOptions = struct {
    imageOrientation: ?enums.ImageOrientation = null,
    premultiplyAlpha: ?enums.PremultiplyAlpha = null,
    colorSpaceConversion: ?enums.ColorSpaceConversion = null,
    resizeWidth: ?u32 = null,
    resizeHeight: ?u32 = null,
    resizeQuality: ?enums.ResizeQuality = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "resizeWidth", "resizeHeight" };
};
