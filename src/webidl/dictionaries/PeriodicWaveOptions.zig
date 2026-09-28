//! WebIDL dictionary: PeriodicWaveOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PeriodicWaveConstraints = @import("PeriodicWaveConstraints.zig").PeriodicWaveConstraints;

pub const PeriodicWaveOptions = struct {
    // Inherited from PeriodicWaveConstraints
    base: PeriodicWaveConstraints,

    real: ?[]const f32 = null,
    imag: ?[]const f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "real", "imag" };
};
