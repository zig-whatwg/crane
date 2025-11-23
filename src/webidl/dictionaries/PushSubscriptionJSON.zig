//! WebIDL dictionary: PushSubscriptionJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PushSubscriptionJSON = struct {
    endpoint: ?runtime.USVString = null,
    expirationTime: ?*const anyopaque = null,
    keys: ?*const anyopaque = null,
};
