//! WebIDL dictionary: ContentDescription
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const ImageResource = @import("ImageResource.zig").ImageResource;

pub const ContentDescription = struct {
    id: runtime.DOMString,
    title: runtime.DOMString,
    description: runtime.DOMString,
    category: ?enums.ContentCategory = null,
    icons: ?[]const ImageResource = null,
    url: runtime.USVString,
};
