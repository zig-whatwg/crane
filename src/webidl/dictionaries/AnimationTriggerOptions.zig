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
    rangeStart: ?*const anyopaque = null,
    rangeEnd: ?*const anyopaque = null,
    exitRangeStart: ?*const anyopaque = null,
    exitRangeEnd: ?*const anyopaque = null,
};
