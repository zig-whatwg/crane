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

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{ "video", "audio" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "video", .{ .boolean = false } },
        .{ "audio", .{ .boolean = false } },
        .{ "preferCurrentTab", .{ .boolean = false } },
    };
};
