//! WebIDL typedef: CryptoKeyOrCryptoKeyPair
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const CryptoKeyOrCryptoKeyPair = union(enum) {
    crypto_key: *runtime.Instance,
    crypto_key_pair: dictionaries.CryptoKeyPair,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "crypto_key", .kind = .{ .interface = "CryptoKey" } },
        .{ .field = "crypto_key_pair", .kind = .dictionary },
    };
};
