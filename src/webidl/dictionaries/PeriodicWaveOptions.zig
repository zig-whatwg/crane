//! WebIDL dictionary: PeriodicWaveOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PeriodicWaveConstraints = @import("PeriodicWaveConstraints.zig").PeriodicWaveConstraints;

pub const PeriodicWaveOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from PeriodicWaveConstraints
    base: PeriodicWaveConstraints,

    real: ?[]const f32 = null,
    imag: ?[]const f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "real", "imag" };
};
