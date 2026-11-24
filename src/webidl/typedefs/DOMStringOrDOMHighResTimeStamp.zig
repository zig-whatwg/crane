//! WebIDL typedef: DOMStringOrDOMHighResTimeStamp
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const DOMStringOrDOMHighResTimeStamp = union(enum) {
    domstring: runtime.DOMString,
    domhigh_res_time_stamp: typedefs.DOMHighResTimeStamp,

    /// WebIDL `double` and `float` arms (not `unrestricted`): a value one of
    /// them takes is a TypeError when NaN or infinite (3.2.5, 3.2.7, 3.2.25).
    pub const restricted_arms = .{"domhigh_res_time_stamp"};

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "domhigh_res_time_stamp", .kind = .numeric },
    };
};
