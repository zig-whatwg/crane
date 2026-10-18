//! WebIDL dictionary: DisplayMediaStreamOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MediaTrackConstraints = @import("MediaTrackConstraints.zig").MediaTrackConstraints;

pub const DisplayMediaStreamOptions = struct {
    video: ?runtime.JSValue = null,
    audio: ?runtime.JSValue = null,
    controller: ?*runtime.Instance = null,
    selfBrowserSurface: ?enums.SelfCapturePreferenceEnum = null,
    systemAudio: ?enums.SystemAudioPreferenceEnum = null,
    windowAudio: ?enums.WindowAudioPreferenceEnum = null,
    surfaceSwitching: ?enums.SurfaceSwitchingPreferenceEnum = null,
    monitorTypeSurfaces: ?enums.MonitorTypeSurfacesEnum = null,
    audioSelection: ?enums.AudioSelectionPreferenceEnum = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{ "video", "audio" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "video", .{ .boolean = true } },
        .{ "audio", .{ .boolean = false } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "controller", "CaptureController" },
    };
};
