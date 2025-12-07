//! WebIDL dictionary: ComputedEffectTiming
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const EffectTiming = @import("EffectTiming.zig").EffectTiming;

pub const ComputedEffectTiming = struct {
    // Inherited from EffectTiming
    base: EffectTiming,

    endTime: ?f64 = null,
    activeDuration: ?f64 = null,
    localTime: ?f64 = null,
    progress: ?f64 = null,
    currentIteration: ?f64 = null,
    startTime: ?typedefs.CSSNumberish = null,
    endTime: ?typedefs.CSSNumberish = null,
    activeDuration: ?typedefs.CSSNumberish = null,
    localTime: ?typedefs.CSSNumberish = null,
};
