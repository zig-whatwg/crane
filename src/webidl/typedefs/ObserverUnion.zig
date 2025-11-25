//! WebIDL typedef: ObserverUnion
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const ObserverUnion = union(enum) {
    variant_0: callbacks.ObservableSubscriptionCallback,
    variant_1: *const anyopaque,
};
