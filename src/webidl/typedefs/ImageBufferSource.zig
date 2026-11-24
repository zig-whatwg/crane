//! WebIDL typedef: ImageBufferSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const ImageBufferSource = union(enum) {
    allow_shared_buffer_source: typedefs.AllowSharedBufferSource,
    readable_stream: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "allow_shared_buffer_source", .kind = .allow_shared_buffer_source },
        .{ .field = "readable_stream", .kind = .{ .interface = "ReadableStream" } },
    };
};
