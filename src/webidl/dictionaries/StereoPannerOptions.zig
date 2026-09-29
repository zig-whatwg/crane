//! WebIDL dictionary: StereoPannerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const StereoPannerOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    pan: ?f32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"pan"};
};
