//! WebIDL dictionary: BiquadFilterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const BiquadFilterOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    type: ?enums.BiquadFilterType = null,
    Q: ?f32 = null,
    detune: ?f32 = null,
    frequency: ?f32 = null,
    gain: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "Q", "detune", "frequency", "gain" };
};
