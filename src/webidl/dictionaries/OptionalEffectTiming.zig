//! WebIDL dictionary: OptionalEffectTiming
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const OptionalEffectTiming = struct {
    delay: ?f64 = null,
    endDelay: ?f64 = null,
    fill: ?enums.FillMode = null,
    iterationStart: ?f64 = null,
    iterations: ?f64 = null,
    duration: ?runtime.JSValue = null,
    direction: ?enums.PlaybackDirection = null,
    easing: ?runtime.DOMString = null,
    playbackRate: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "delay", "endDelay", "iterationStart", "playbackRate" };

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"duration"};
};
