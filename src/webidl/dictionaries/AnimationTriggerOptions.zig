//! WebIDL dictionary: AnimationTriggerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const enums = @import("enums");
const TimelineRangeOffset = @import("TimelineRangeOffset.zig").TimelineRangeOffset;

pub const AnimationTriggerOptions = struct {
    timeline: ?*runtime.Instance = null,
    behavior: webidl.Opt(?enums.AnimationTriggerBehavior) = .notPassed(),
    activationRangeStart: ?runtime.JSValue = null,
    activationRangeEnd: ?runtime.JSValue = null,
    activeRangeStart: ?runtime.JSValue = null,
    activeRangeEnd: ?runtime.JSValue = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "timeline", "behavior" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "timeline", "AnimationTimeline" },
    };
};
