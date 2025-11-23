//! WebIDL dictionary: ContentDescription
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ContentDescription = struct {
    id: runtime.DOMString,
    title: runtime.DOMString,
    description: runtime.DOMString,
    category: ?*const anyopaque = null,
    icons: ?*const anyopaque = null,
    url: runtime.USVString,
};
