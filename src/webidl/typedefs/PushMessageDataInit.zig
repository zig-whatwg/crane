//! WebIDL typedef: PushMessageDataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const PushMessageDataInit = union(enum) {
    buffer_source: typedefs.BufferSource,
    usvstring: runtime.USVString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "buffer_source", .kind = .buffer_source },
        .{ .field = "usvstring", .kind = .string },
    };
};
