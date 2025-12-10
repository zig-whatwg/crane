//! WebIDL dictionary: AnimationTriggerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const TimelineRangeOffset = @import("TimelineRangeOffset.zig").TimelineRangeOffset;

pub const AnimationTriggerOptions = struct {
    timeline: ?*runtime.Instance = null,
    behavior: ?enums.AnimationTriggerBehavior = null,
    rangeStart: ?runtime.JSValue = null,
    rangeEnd: ?runtime.JSValue = null,
    exitRangeStart: ?runtime.JSValue = null,
    exitRangeEnd: ?runtime.JSValue = null,
};
