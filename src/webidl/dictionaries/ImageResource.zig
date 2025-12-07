//! WebIDL dictionary: ImageResource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ImageResource = struct {
    src: runtime.USVString,
    sizes: ?runtime.DOMString = null,
    @"type": ?runtime.DOMString = null,
    label: ?runtime.DOMString = null,
};
