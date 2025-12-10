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
};
