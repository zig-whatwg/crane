//! WebIDL dictionary: KeyframeEffectOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const EffectTiming = @import("EffectTiming.zig").EffectTiming;

pub const KeyframeEffectOptions = struct {
    // Inherited from EffectTiming
    base: EffectTiming,

    composite: ?enums.CompositeOperation = null,
    pseudoElement: ?typedefs.CSSOMString = null,
    iterationComposite: ?enums.IterationCompositeOperation = null,
};
