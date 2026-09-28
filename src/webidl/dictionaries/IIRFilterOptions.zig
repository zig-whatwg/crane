//! WebIDL dictionary: IIRFilterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const IIRFilterOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    feedforward: []const f64,
    feedback: []const f64,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "feedforward", "feedback" };
};
