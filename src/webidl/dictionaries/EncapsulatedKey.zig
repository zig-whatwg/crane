//! WebIDL dictionary: EncapsulatedKey
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EncapsulatedKey = struct {
    sharedKey: ?*const anyopaque = null,
    ciphertext: ?*const anyopaque = null,
};
