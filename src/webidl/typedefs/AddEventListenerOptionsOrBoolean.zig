//! WebIDL typedef: AddEventListenerOptionsOrBoolean
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const AddEventListenerOptionsOrBoolean = union(enum) {
    add_event_listener_options: dictionaries.AddEventListenerOptions,
    boolean: bool,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "add_event_listener_options", .kind = .dictionary },
        .{ .field = "boolean", .kind = .boolean },
    };
};
