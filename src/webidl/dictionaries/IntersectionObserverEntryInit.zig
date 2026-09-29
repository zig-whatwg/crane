//! WebIDL dictionary: IntersectionObserverEntryInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const DOMRectInit = @import("DOMRectInit.zig").DOMRectInit;

pub const IntersectionObserverEntryInit = struct {
    time: typedefs.DOMHighResTimeStamp,
    rootBounds: DOMRectInit,
    boundingClientRect: DOMRectInit,
    intersectionRect: DOMRectInit,
    isIntersecting: bool,
    isVisible: bool,
    intersectionRatio: f64,
    target: *runtime.Instance,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "time", "intersectionRatio" };
};
