//! WebIDL typedef: ObserverUnion
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary/callback types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");

pub const ObserverUnion = union(enum) {
    observable_subscription_callback: *runtime.Instance,
    subscription_observer: *runtime.Instance,
};
