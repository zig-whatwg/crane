//! WebIDL dictionary: BackgroundFetchUIOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ImageResource = @import("ImageResource.zig").ImageResource;

pub const BackgroundFetchUIOptions = struct {
    icons: ?[]const ImageResource = null,
    title: ?runtime.DOMString = null,
};
