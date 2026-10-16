//! WebIDL dictionary: ConvolverOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const ConvolverOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    buffer: ?*runtime.Instance = null,
    disableNormalization: ?bool = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"buffer"};
};
