//! WebIDL dictionary: VideoEncoderEncodeOptionsForAv1
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoEncoderEncodeOptionsForAv1 = struct {
    quantizer: ?u16 = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"quantizer"};
};
