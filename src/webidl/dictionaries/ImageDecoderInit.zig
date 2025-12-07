//! WebIDL dictionary: ImageDecoderInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const ImageDecoderInit = struct {
    @"type": runtime.DOMString,
    data: typedefs.ImageBufferSource,
    colorSpaceConversion: ?enums.ColorSpaceConversion = null,
    desiredWidth: ?u32 = null,
    desiredHeight: ?u32 = null,
    preferAnimation: ?bool = null,
    transfer: ?[]const *const anyopaque = null,
};
