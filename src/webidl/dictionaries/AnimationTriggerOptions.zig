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

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{ "activationRangeStart", "activationRangeEnd", "activeRangeStart", "activeRangeEnd" };

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
