//! WebIDL dictionary: EcKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const KeyAlgorithm = @import("KeyAlgorithm.zig").KeyAlgorithm;

pub const EcKeyAlgorithm = struct {
    // Inherited from KeyAlgorithm
    base: KeyAlgorithm,

    namedCurve: typedefs.NamedCurve,
};
