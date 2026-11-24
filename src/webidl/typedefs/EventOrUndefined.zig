//! WebIDL typedef: EventOrUndefined
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const EventOrUndefined = union(enum) {
    event: *runtime.Instance,
    undefined: void,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "event", .kind = .{ .interface = "Event" } },
        .{ .field = "undefined", .kind = .undefined },
    };
};
