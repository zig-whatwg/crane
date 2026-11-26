//! WebIDL dictionary: KeyframeAnimationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("typedefs");
const KeyframeEffectOptions = @import("KeyframeEffectOptions.zig").KeyframeEffectOptions;

pub const KeyframeAnimationOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from KeyframeEffectOptions
    base: KeyframeEffectOptions,

    id: ?runtime.DOMString = null,
    timeline: webidl.Opt(?*runtime.Instance) = .notPassed(),
    rangeStart: ?typedefs.TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString = null,
    rangeEnd: ?typedefs.TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString = null,
    trigger: ?*runtime.Instance = null,

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
