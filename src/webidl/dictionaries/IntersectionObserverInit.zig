//! WebIDL dictionary: IntersectionObserverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const IntersectionObserverInit = struct {
    root: ?runtime.JSValue = null,
    rootMargin: ?runtime.DOMString = null,
    scrollMargin: ?runtime.DOMString = null,
    threshold: ?runtime.JSValue = null,
    delay: ?i32 = null,
    trackVisibility: ?bool = null,
};
