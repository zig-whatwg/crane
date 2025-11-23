//! WebIDL dictionary: PushSubscriptionChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PushSubscriptionChangeEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    newSubscription: ?*const anyopaque = null,
    oldSubscription: ?*const anyopaque = null,
};
