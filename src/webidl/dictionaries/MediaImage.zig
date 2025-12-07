//! WebIDL dictionary: MediaImage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const MediaImage = struct {
    src: runtime.USVString,
    sizes: ?runtime.DOMString = null,
    @"type": ?runtime.DOMString = null,
};
