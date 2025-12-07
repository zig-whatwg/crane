//! WebIDL dictionary: OptionalEffectTiming
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const OptionalEffectTiming = struct {
    delay: ?f64 = null,
    endDelay: ?f64 = null,
    fill: ?enums.FillMode = null,
    iterationStart: ?f64 = null,
    iterations: ?f64 = null,
    duration: ?*const anyopaque = null,
    direction: ?enums.PlaybackDirection = null,
    easing: ?runtime.DOMString = null,
    playbackRate: ?f64 = null,
};
