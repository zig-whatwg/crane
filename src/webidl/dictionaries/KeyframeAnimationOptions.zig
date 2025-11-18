//! WebIDL dictionary: KeyframeAnimationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const KeyframeEffectOptions = @import("KeyframeEffectOptions.zig").KeyframeEffectOptions;

pub const KeyframeAnimationOptions = struct {
    // Inherited from KeyframeEffectOptions
    base: KeyframeEffectOptions,

    id: ?runtime.DOMString = null,
    timeline: ?anyopaque = null,
};
