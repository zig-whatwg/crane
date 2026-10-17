//! WebIDL dictionary: IntersectionObserverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IntersectionObserverInit = struct {
    root: ?runtime.JSValue = null,
    rootMargin: ?runtime.DOMString = null,
    scrollMargin: ?runtime.DOMString = null,
    threshold: ?runtime.JSValue = null,
    delay: ?i32 = null,
    trackVisibility: ?bool = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"root"};
};
