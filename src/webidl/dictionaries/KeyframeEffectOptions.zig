//! WebIDL dictionary: KeyframeEffectOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EffectTiming = @import("EffectTiming.zig").EffectTiming;

pub const KeyframeEffectOptions = struct {
    // Inherited from EffectTiming
    base: EffectTiming,

    composite: ?anyopaque = null,
    pseudoElement: ?anyopaque = null,
};
