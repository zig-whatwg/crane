//! WebIDL dictionary: HmacKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const KeyAlgorithm = @import("KeyAlgorithm.zig").KeyAlgorithm;

pub const HmacKeyAlgorithm = struct {
    // Inherited from KeyAlgorithm
    base: KeyAlgorithm,

    hash: KeyAlgorithm,
    length: u32,
};
