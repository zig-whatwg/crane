//! WebIDL typedef: ObservableInspectorUnion
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");
const dictionaries = @import("dictionaries");

pub const ObservableInspectorUnion = union(enum) {
    observable_subscription_callback: callbacks.ObservableSubscriptionCallback,
    observable_inspector: dictionaries.ObservableInspector,
};
