//! WebIDL dictionary: PushSubscriptionJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PushSubscriptionJSON = struct {
    endpoint: ?runtime.USVString = null,
    expirationTime: ?typedefs.EpochTimeStamp = null,
    keys: ?[]const struct { key: runtime.DOMString, value: runtime.USVString } = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"expirationTime"};
};
