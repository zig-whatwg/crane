//! WebIDL dictionary: ComputedEffectTiming
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("typedefs");
const EffectTiming = @import("EffectTiming.zig").EffectTiming;

pub const ComputedEffectTiming = struct {
    // Inherited from EffectTiming
    base: EffectTiming,

    progress: webidl.Opt(?f64) = .notPassed(),
    currentIteration: webidl.Opt(?f64) = .notPassed(),
    startTime: ?typedefs.CSSNumberish = null,
    endTime: ?typedefs.CSSNumberish = null,
    activeDuration: ?typedefs.CSSNumberish = null,
    localTime: webidl.Opt(?typedefs.CSSNumberish) = .notPassed(),

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"progress"};

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "progress", "currentIteration", "localTime" };
};
