//! WebIDL dictionary: IntersectionObserverEntryInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IntersectionObserverEntryInit = struct {
    time: anyopaque,
    rootBounds: anyopaque,
    boundingClientRect: anyopaque,
    intersectionRect: anyopaque,
    isIntersecting: bool,
    isVisible: bool,
    intersectionRatio: f64,
    target: anyopaque,
};
