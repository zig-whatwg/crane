//! WebIDL dictionary: HTMLMediaStreamConstraints
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MediaTrackConstraintSet = @import("MediaTrackConstraintSet.zig").MediaTrackConstraintSet;

pub const HTMLMediaStreamConstraints = struct {
    video: ?MediaTrackConstraintSet = null,
    audio: ?MediaTrackConstraintSet = null,
};
