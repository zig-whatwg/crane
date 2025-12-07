//! WebIDL dictionary: ObservableInspector
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const ObservableInspector = struct {
    next: ?callbacks.ObservableSubscriptionCallback = null,
    @"error": ?callbacks.ObservableSubscriptionCallback = null,
    complete: ?callbacks.VoidFunction = null,
    subscribe: ?callbacks.VoidFunction = null,
    abort: ?callbacks.ObservableInspectorAbortHandler = null,
};
