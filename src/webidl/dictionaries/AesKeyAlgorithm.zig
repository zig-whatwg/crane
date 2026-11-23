//! WebIDL dictionary: AesKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const KeyAlgorithm = @import("KeyAlgorithm.zig").KeyAlgorithm;

pub const AesKeyAlgorithm = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from KeyAlgorithm
    base: KeyAlgorithm,

    length: u16,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"length"};
};
