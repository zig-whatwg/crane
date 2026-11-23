//! WebIDL dictionary: ImageResource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImageResource = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    src: runtime.USVString,
    sizes: ?runtime.DOMString = null,
    type: ?runtime.DOMString = null,
    label: ?runtime.DOMString = null,
};
