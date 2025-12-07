//! WebIDL dictionary: KeyframeAnimationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const TimelineRangeOffset = @import("TimelineRangeOffset.zig").TimelineRangeOffset;
const KeyframeEffectOptions = @import("KeyframeEffectOptions.zig").KeyframeEffectOptions;

pub const KeyframeAnimationOptions = struct {
    // Inherited from KeyframeEffectOptions
    base: KeyframeEffectOptions,

    id: ?runtime.DOMString = null,
    timeline: ?*runtime.Instance = null,
    rangeStart: ?*const anyopaque = null,
    rangeEnd: ?*const anyopaque = null,
    trigger: ?*runtime.Instance = null,
};
