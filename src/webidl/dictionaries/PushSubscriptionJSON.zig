//! WebIDL dictionary: PushSubscriptionJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PushSubscriptionJSON = struct {
    endpoint: ?runtime.USVString = null,
    expirationTime: ?typedefs.EpochTimeStamp = null,
    keys: ?[]const struct { key: runtime.DOMString, value: runtime.USVString } = null,
};
