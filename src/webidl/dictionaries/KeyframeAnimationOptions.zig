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

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{ "rangeStart", "rangeEnd" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "id", .{ .string = "" } },
        .{ "rangeStart", .{ .string = "normal" } },
        .{ "rangeEnd", .{ .string = "normal" } },
    };

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
