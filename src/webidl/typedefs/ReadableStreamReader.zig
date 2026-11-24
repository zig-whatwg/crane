//! WebIDL typedef: ReadableStreamReader
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const ReadableStreamReader = union(enum) {
    readable_stream_default_reader: *runtime.Instance,
    readable_stream_byobreader: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "readable_stream_default_reader", .kind = .{ .interface = "ReadableStreamDefaultReader" } },
        .{ .field = "readable_stream_byobreader", .kind = .{ .interface = "ReadableStreamBYOBReader" } },
    };
};
