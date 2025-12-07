//! WebIDL dictionary: FontFaceDescriptors
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const FontFaceDescriptors = struct {
    style: ?typedefs.CSSOMString = null,
    weight: ?typedefs.CSSOMString = null,
    stretch: ?typedefs.CSSOMString = null,
    unicodeRange: ?typedefs.CSSOMString = null,
    featureSettings: ?typedefs.CSSOMString = null,
    variationSettings: ?typedefs.CSSOMString = null,
    display: ?typedefs.CSSOMString = null,
    ascentOverride: ?typedefs.CSSOMString = null,
    descentOverride: ?typedefs.CSSOMString = null,
    lineGapOverride: ?typedefs.CSSOMString = null,
};
