//! WebIDL typedef: RequestInfoOrSequenceOfRequestInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const RequestInfoOrSequenceOfRequestInfo = union(enum) {
    request_info: typedefs.RequestInfo,
    request_info_sequence: []const typedefs.RequestInfo,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "request_info", .kind = .@"union" },
        .{ .field = "request_info_sequence", .kind = .{ .sequence = null } },
    };
};
