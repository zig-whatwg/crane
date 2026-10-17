//! WebIDL dictionary: KeyframeAnimationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const TimelineRangeOffset = @import("TimelineRangeOffset.zig").TimelineRangeOffset;
const KeyframeEffectOptions = @import("KeyframeEffectOptions.zig").KeyframeEffectOptions;

pub const KeyframeAnimationOptions = struct {
    // Inherited from KeyframeEffectOptions
    base: KeyframeEffectOptions,

    id: ?runtime.DOMString = null,
    timeline: ?*runtime.Instance = null,
    rangeStart: ?runtime.JSValue = null,
    rangeEnd: ?runtime.JSValue = null,
    trigger: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "timeline", "trigger" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "timeline", "AnimationTimeline" },
        .{ "trigger", "AnimationTrigger" },
    };
};
