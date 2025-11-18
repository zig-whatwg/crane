//! WebIDL dictionary: PannerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const PannerOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    panningModel: ?anyopaque = null,
    distanceModel: ?anyopaque = null,
    positionX: ?f32 = null,
    positionY: ?f32 = null,
    positionZ: ?f32 = null,
    orientationX: ?f32 = null,
    orientationY: ?f32 = null,
    orientationZ: ?f32 = null,
    refDistance: ?f64 = null,
    maxDistance: ?f64 = null,
    rolloffFactor: ?f64 = null,
    coneInnerAngle: ?f64 = null,
    coneOuterAngle: ?f64 = null,
    coneOuterGain: ?f64 = null,
};
