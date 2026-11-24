//! WebIDL typedef: BlobOrMediaSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const BlobOrMediaSource = union(enum) {
    blob: *runtime.Instance,
    media_source: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "blob", .kind = .{ .interface = "Blob" } },
        .{ .field = "media_source", .kind = .{ .interface = "MediaSource" } },
    };
};
