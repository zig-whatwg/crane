//! WebIDL typedef: ObserverUnion
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const dictionaries = @import("dictionaries");

pub const ObserverUnion = union(enum) {
    observable_subscription_callback: callbacks.ObservableSubscriptionCallback,
    subscription_observer: dictionaries.SubscriptionObserver,
};
