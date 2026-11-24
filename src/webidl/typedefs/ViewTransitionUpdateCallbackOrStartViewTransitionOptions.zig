//! WebIDL typedef: ViewTransitionUpdateCallbackOrStartViewTransitionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const callbacks = @import("callbacks");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const ViewTransitionUpdateCallbackOrStartViewTransitionOptions = union(enum) {
    view_transition_update_callback: callbacks.ViewTransitionUpdateCallback,
    start_view_transition_options: dictionaries.StartViewTransitionOptions,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "view_transition_update_callback", .kind = .callback_function },
        .{ .field = "start_view_transition_options", .kind = .dictionary },
    };
};
