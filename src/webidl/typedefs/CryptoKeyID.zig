//! WebIDL typedef: CryptoKeyID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const CryptoKeyID = union(enum) {
    small_crypto_key_id: typedefs.SmallCryptoKeyID,
    bigint: runtime.JSValue,
};
