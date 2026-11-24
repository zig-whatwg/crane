//! WebIDL typedef: MediaProvider
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const MediaProvider = union(enum) {
    media_stream: *runtime.Instance,
    media_source: *runtime.Instance,
    blob: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "media_stream", .kind = .{ .interface = "MediaStream" } },
        .{ .field = "media_source", .kind = .{ .interface = "MediaSource" } },
        .{ .field = "blob", .kind = .{ .interface = "Blob" } },
    };
};
