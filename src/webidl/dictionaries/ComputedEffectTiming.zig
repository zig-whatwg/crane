//! WebIDL dictionary: ComputedEffectTiming
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EffectTiming = @import("EffectTiming.zig").EffectTiming;

pub const ComputedEffectTiming = struct {
    // Inherited from EffectTiming
    base: EffectTiming,

    endTime: ?f64 = null,
    activeDuration: ?f64 = null,
    localTime: ?f64 = null,
    progress: ?f64 = null,
    currentIteration: ?f64 = null,
};
