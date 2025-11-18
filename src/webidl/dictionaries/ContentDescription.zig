//! WebIDL dictionary: ContentDescription
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ContentDescription = struct {
    id: runtime.DOMString,
    title: runtime.DOMString,
    description: runtime.DOMString,
    category: ?anyopaque = null,
    icons: ?anyopaque = null,
    url: runtime.DOMString,
};
