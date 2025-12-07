//! WebIDL dictionary: DisplayMediaStreamOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const MediaTrackConstraints = @import("MediaTrackConstraints.zig").MediaTrackConstraints;

pub const DisplayMediaStreamOptions = struct {
    video: ?*const anyopaque = null,
    audio: ?*const anyopaque = null,
    controller: ?*runtime.Instance = null,
    selfBrowserSurface: ?enums.SelfCapturePreferenceEnum = null,
    systemAudio: ?enums.SystemAudioPreferenceEnum = null,
    windowAudio: ?enums.WindowAudioPreferenceEnum = null,
    surfaceSwitching: ?enums.SurfaceSwitchingPreferenceEnum = null,
    monitorTypeSurfaces: ?enums.MonitorTypeSurfacesEnum = null,
};
