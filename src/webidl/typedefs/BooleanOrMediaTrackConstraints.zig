//! WebIDL typedef: BooleanOrMediaTrackConstraints
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const BooleanOrMediaTrackConstraints = union(enum) {
    boolean: bool,
    media_track_constraints: dictionaries.MediaTrackConstraints,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "boolean", .kind = .boolean },
        .{ .field = "media_track_constraints", .kind = .dictionary },
    };
};
