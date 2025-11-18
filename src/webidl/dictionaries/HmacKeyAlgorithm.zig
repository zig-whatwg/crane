//! WebIDL dictionary: HmacKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const KeyAlgorithm = @import("KeyAlgorithm.zig").KeyAlgorithm;

pub const HmacKeyAlgorithm = struct {
    // Inherited from KeyAlgorithm
    base: KeyAlgorithm,

    hash: anyopaque,
    length: u32,
};
