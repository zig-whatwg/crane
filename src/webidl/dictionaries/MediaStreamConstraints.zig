//! WebIDL dictionary: MediaStreamConstraints
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const MediaTrackConstraints = @import("MediaTrackConstraints.zig").MediaTrackConstraints;

pub const MediaStreamConstraints = struct {
    video: ?*const anyopaque = null,
    audio: ?*const anyopaque = null,
    preferCurrentTab: ?bool = null,
    peerIdentity: ?runtime.DOMString = null,
};
