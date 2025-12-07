//! WebIDL dictionary: SubscriptionObserver
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");

pub const SubscriptionObserver = struct {
    next: ?callbacks.ObservableSubscriptionCallback = null,
    @"error": ?callbacks.ObservableSubscriptionCallback = null,
    complete: ?callbacks.VoidFunction = null,
};
