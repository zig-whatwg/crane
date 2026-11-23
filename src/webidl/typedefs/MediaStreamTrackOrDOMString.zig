//! WebIDL typedef: MediaStreamTrackOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const MediaStreamTrackOrDOMString = union(enum) {
    media_stream_track: *runtime.Instance,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "media_stream_track", .kind = .{ .interface = "MediaStreamTrack" } },
        .{ .field = "domstring", .kind = .string },
    };
};
