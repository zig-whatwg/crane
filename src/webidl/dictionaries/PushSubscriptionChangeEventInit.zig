//! WebIDL dictionary: PushSubscriptionChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PushSubscriptionChangeEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    newSubscription: ?*runtime.Instance = null,
    oldSubscription: ?*runtime.Instance = null,
};
