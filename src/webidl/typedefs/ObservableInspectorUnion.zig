//! WebIDL typedef: ObservableInspectorUnion
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary/callback types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");

pub const ObservableInspectorUnion = union(enum) {
    observable_subscription_callback: *runtime.Instance,
    observable_inspector: *runtime.Instance,
};
