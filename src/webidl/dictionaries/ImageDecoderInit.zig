//! WebIDL dictionary: ImageDecoderInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImageDecoderInit = struct {
    type: runtime.DOMString,
    data: *const anyopaque,
    colorSpaceConversion: ?*const anyopaque = null,
    desiredWidth: ?u32 = null,
    desiredHeight: ?u32 = null,
    preferAnimation: ?bool = null,
    transfer: ?*const anyopaque = null,
};
