//! WebIDL dictionary: HTMLMediaStreamConstraints
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MediaTrackConstraintSet = @import("MediaTrackConstraintSet.zig").MediaTrackConstraintSet;

pub const HTMLMediaStreamConstraints = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    video: ?MediaTrackConstraintSet = null,
    audio: ?MediaTrackConstraintSet = null,
};
