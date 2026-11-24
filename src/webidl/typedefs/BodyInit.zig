//! WebIDL typedef: BodyInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const BodyInit = union(enum) {
    readable_stream: *runtime.Instance,
    xmlhttp_request_body_init: typedefs.XMLHttpRequestBodyInit,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "readable_stream", .kind = .{ .interface = "ReadableStream" } },
        .{ .field = "xmlhttp_request_body_init", .kind = .@"union" },
    };
};
