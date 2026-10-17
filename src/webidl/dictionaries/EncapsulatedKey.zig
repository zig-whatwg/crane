//! WebIDL dictionary: EncapsulatedKey
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EncapsulatedKey = struct {
    sharedKey: ?*runtime.Instance = null,
    ciphertext: ?runtime.JSValue = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "sharedKey", "CryptoKey" },
    };
};
