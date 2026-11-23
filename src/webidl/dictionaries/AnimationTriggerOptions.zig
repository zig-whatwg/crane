//! WebIDL dictionary: AnimationTriggerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const AnimationTriggerOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    timeline: ?*runtime.Instance = null,
    behavior: webidl.Opt(?enums.AnimationTriggerBehavior) = .notPassed(),
    activationRangeStart: ?typedefs.TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString = null,
    activationRangeEnd: ?typedefs.TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString = null,
    activeRangeStart: ?typedefs.TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString = null,
    activeRangeEnd: ?typedefs.TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "behavior", .{ .string = "once" } },
        .{ "activationRangeStart", .{ .string = "normal" } },
        .{ "activationRangeEnd", .{ .string = "normal" } },
        .{ "activeRangeStart", .{ .string = "auto" } },
        .{ "activeRangeEnd", .{ .string = "auto" } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "timeline", "behavior" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "timeline", "AnimationTimeline" },
    };
};
