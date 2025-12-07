//! WebIDL dictionary: PeriodicWaveOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const PeriodicWaveConstraints = @import("PeriodicWaveConstraints.zig").PeriodicWaveConstraints;

pub const PeriodicWaveOptions = struct {
    // Inherited from PeriodicWaveConstraints
    base: PeriodicWaveConstraints,

    real: ?[]const f32 = null,
    imag: ?[]const f32 = null,
};
