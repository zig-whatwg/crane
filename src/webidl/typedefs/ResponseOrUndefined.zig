//! WebIDL typedef: ResponseOrUndefined
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const ResponseOrUndefined = union(enum) {
    response: *runtime.Instance,
    undefined: void,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "response", .kind = .{ .interface = "Response" } },
        .{ .field = "undefined", .kind = .undefined },
    };
};
