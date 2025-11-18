//! WebIDL dictionary: PeriodicWaveOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PeriodicWaveConstraints = @import("PeriodicWaveConstraints.zig").PeriodicWaveConstraints;

pub const PeriodicWaveOptions = struct {
    // Inherited from PeriodicWaveConstraints
    base: PeriodicWaveConstraints,

    real: ?anyopaque = null,
    imag: ?anyopaque = null,
};
