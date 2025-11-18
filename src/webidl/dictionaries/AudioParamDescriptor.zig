//! WebIDL dictionary: AudioParamDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioParamDescriptor = struct {
    name: runtime.DOMString,
    defaultValue: ?f32 = null,
    minValue: ?f32 = null,
    maxValue: ?f32 = null,
    automationRate: ?anyopaque = null,
};
