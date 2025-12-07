//! WebIDL typedef: ObserverUnion
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");

pub const ObserverUnion = union(enum) {
    observable_subscription_callback: callbacks.ObservableSubscriptionCallback,
    subscription_observer: dictionaries.SubscriptionObserver,
};
