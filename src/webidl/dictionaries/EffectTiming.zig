//! WebIDL dictionary: EffectTiming
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const EffectTiming = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    fill: ?enums.FillMode = null,
    iterationStart: ?f64 = null,
    iterations: ?f64 = null,
    direction: ?enums.PlaybackDirection = null,
    easing: ?runtime.DOMString = null,
    delay: ?f64 = null,
    endDelay: ?f64 = null,
    playbackRate: ?f64 = null,
    duration: ?typedefs.UnrestrictedDoubleOrCSSNumericValueOrDOMString = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "iterationStart", "delay", "endDelay", "playbackRate" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "fill", .{ .string = "auto" } },
        .{ "iterationStart", .{ .number = 0 } },
        .{ "iterations", .{ .number = 1 } },
        .{ "direction", .{ .string = "normal" } },
        .{ "easing", .{ .string = "linear" } },
        .{ "playbackRate", .{ .number = 1 } },
        .{ "duration", .{ .string = "auto" } },
    };
};
