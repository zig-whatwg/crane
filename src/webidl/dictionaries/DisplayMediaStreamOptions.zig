//! WebIDL dictionary: DisplayMediaStreamOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const DisplayMediaStreamOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    video: ?typedefs.BooleanOrMediaTrackConstraints = null,
    audio: ?typedefs.BooleanOrMediaTrackConstraints = null,
    controller: ?*runtime.Instance = null,
    selfBrowserSurface: ?enums.SelfCapturePreferenceEnum = null,
    systemAudio: ?enums.SystemAudioPreferenceEnum = null,
    windowAudio: ?enums.WindowAudioPreferenceEnum = null,
    surfaceSwitching: ?enums.SurfaceSwitchingPreferenceEnum = null,
    monitorTypeSurfaces: ?enums.MonitorTypeSurfacesEnum = null,
    audioSelection: ?enums.AudioSelectionPreferenceEnum = null,

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
