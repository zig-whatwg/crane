//! WebIDL dictionary: RsaKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const KeyAlgorithm = @import("KeyAlgorithm.zig").KeyAlgorithm;

pub const RsaKeyAlgorithm = struct {
    // Inherited from KeyAlgorithm
    base: KeyAlgorithm,

    modulusLength: u32,
    publicExponent: anyopaque,
};
