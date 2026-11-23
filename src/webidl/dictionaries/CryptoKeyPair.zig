//! WebIDL dictionary: CryptoKeyPair
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CryptoKeyPair = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    publicKey: ?*runtime.Instance = null,
    privateKey: ?*runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "publicKey", "CryptoKey" },
        .{ "privateKey", "CryptoKey" },
    };
};
