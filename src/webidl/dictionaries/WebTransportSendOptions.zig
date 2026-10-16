//! WebIDL dictionary: WebTransportSendOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WebTransportSendOptions = struct {
    sendGroup: ?*runtime.Instance = null,
    sendOrder: ?i64 = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"sendGroup"};
};
