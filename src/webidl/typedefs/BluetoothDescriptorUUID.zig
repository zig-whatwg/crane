//! WebIDL typedef: BluetoothDescriptorUUID
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const BluetoothDescriptorUUID = union(enum) {
    domstring: runtime.DOMString,
    ulong: u32,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "ulong", .kind = .numeric },
    };
};
