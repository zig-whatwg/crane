//! WebIDL typedef: CryptoKeyID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const CryptoKeyID = union(enum) {
    small_crypto_key_id: typedefs.SmallCryptoKeyID,
    bigint: runtime.JSValue,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "small_crypto_key_id", .kind = .numeric },
        .{ .field = "bigint", .kind = .bigint },
    };
};
