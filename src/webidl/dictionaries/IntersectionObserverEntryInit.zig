//! WebIDL dictionary: IntersectionObserverEntryInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IntersectionObserverEntryInit = struct {
    time: *const anyopaque,
    rootBounds: *const anyopaque,
    boundingClientRect: *const anyopaque,
    intersectionRect: *const anyopaque,
    isIntersecting: bool,
    isVisible: bool,
    intersectionRatio: f64,
    target: *const anyopaque,
};
