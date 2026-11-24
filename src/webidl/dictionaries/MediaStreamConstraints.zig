//! WebIDL dictionary: MediaStreamConstraints
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const MediaStreamConstraints = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    video: ?typedefs.BooleanOrMediaTrackConstraints = null,
    audio: ?typedefs.BooleanOrMediaTrackConstraints = null,
    semantics: ?enums.GetUserMediaSemantics = null,
    preferCurrentTab: ?bool = null,
    peerIdentity: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "video", .{ .boolean = false } },
        .{ "audio", .{ .boolean = false } },
        .{ "preferCurrentTab", .{ .boolean = false } },
    };
};
