//! WebIDL dictionary: ObservableInspector
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const ObservableInspector = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    next: ?callbacks.ObservableSubscriptionCallback = null,
    @"error": ?callbacks.ObservableSubscriptionCallback = null,
    complete: ?callbacks.VoidFunction = null,
    subscribe: ?callbacks.VoidFunction = null,
    abort: ?callbacks.ObservableInspectorAbortHandler = null,
};
