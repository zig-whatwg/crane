//! WebIDL dictionary: EffectTiming
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EffectTiming = struct {
    delay: ?f64 = null,
    endDelay: ?f64 = null,
    fill: ?*const anyopaque = null,
    iterationStart: ?f64 = null,
    iterations: ?f64 = null,
    duration: ?*const anyopaque = null,
    direction: ?*const anyopaque = null,
    easing: ?runtime.DOMString = null,
};
