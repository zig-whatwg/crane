//! WebIDL dictionary: EcdhKeyDeriveParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const EcdhKeyDeriveParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    public: *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "public", "CryptoKey" },
    };
};
