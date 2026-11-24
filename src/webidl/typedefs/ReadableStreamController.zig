//! WebIDL typedef: ReadableStreamController
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const ReadableStreamController = union(enum) {
    readable_stream_default_controller: *runtime.Instance,
    readable_byte_stream_controller: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "readable_stream_default_controller", .kind = .{ .interface = "ReadableStreamDefaultController" } },
        .{ .field = "readable_byte_stream_controller", .kind = .{ .interface = "ReadableByteStreamController" } },
    };
};
