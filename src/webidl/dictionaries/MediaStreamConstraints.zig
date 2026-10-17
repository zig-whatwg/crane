//! WebIDL dictionary: MediaStreamConstraints
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MediaTrackConstraints = @import("MediaTrackConstraints.zig").MediaTrackConstraints;

pub const MediaStreamConstraints = struct {
    video: ?runtime.JSValue = null,
    audio: ?runtime.JSValue = null,
    semantics: ?enums.GetUserMediaSemantics = null,
    preferCurrentTab: ?bool = null,
    peerIdentity: ?runtime.DOMString = null,
};
