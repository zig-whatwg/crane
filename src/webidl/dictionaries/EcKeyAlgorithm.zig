//! WebIDL dictionary: EcKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const KeyAlgorithm = @import("KeyAlgorithm.zig").KeyAlgorithm;

pub const EcKeyAlgorithm = struct {
    // Inherited from KeyAlgorithm
    base: KeyAlgorithm,

    namedCurve: anyopaque,
};
