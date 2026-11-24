//! WebIDL typedef: ObservableInspectorUnion
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const callbacks = @import("callbacks");
const dictionaries = @import("dictionaries");

pub const ObservableInspectorUnion = union(enum) {
    observable_subscription_callback: callbacks.ObservableSubscriptionCallback,
    observable_inspector: dictionaries.ObservableInspector,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "observable_subscription_callback", .kind = .callback_function },
        .{ .field = "observable_inspector", .kind = .dictionary },
    };
};
