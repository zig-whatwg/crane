//! WebIDL dictionary: BackgroundFetchUIOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ImageResource = @import("ImageResource.zig").ImageResource;

pub const BackgroundFetchUIOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    icons: ?[]const ImageResource = null,
    title: ?runtime.DOMString = null,
};
