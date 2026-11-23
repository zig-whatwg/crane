//! WebIDL dictionary: RsaHashedKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const KeyAlgorithm = @import("KeyAlgorithm.zig").KeyAlgorithm;
const RsaKeyAlgorithm = @import("RsaKeyAlgorithm.zig").RsaKeyAlgorithm;

pub const RsaHashedKeyAlgorithm = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from RsaKeyAlgorithm
    base: RsaKeyAlgorithm,

    hash: KeyAlgorithm,
};
