//! WebIDL dictionary: MediaTrackConstraints
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MediaTrackConstraintSet = @import("MediaTrackConstraintSet.zig").MediaTrackConstraintSet;

pub const MediaTrackConstraints = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from MediaTrackConstraintSet
    base: MediaTrackConstraintSet,

    advanced: ?[]const MediaTrackConstraintSet = null,
};
