//! WebIDL dictionary: PerformanceMeasureOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PerformanceMeasureOptions = struct {
    detail: ?runtime.JSValue = null,
    start: ?runtime.JSValue = null,
    duration: ?typedefs.DOMHighResTimeStamp = null,
    end: ?runtime.JSValue = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"duration"};
};
