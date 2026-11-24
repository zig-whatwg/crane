//! WebIDL typedef: RequestInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const RequestInfo = union(enum) {
    request: *runtime.Instance,
    usvstring: runtime.USVString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "request", .kind = .{ .interface = "Request" } },
        .{ .field = "usvstring", .kind = .string },
    };
};
