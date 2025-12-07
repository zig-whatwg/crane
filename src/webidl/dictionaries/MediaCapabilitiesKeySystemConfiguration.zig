//! WebIDL dictionary: MediaCapabilitiesKeySystemConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const KeySystemTrackConfiguration = @import("KeySystemTrackConfiguration.zig").KeySystemTrackConfiguration;

pub const MediaCapabilitiesKeySystemConfiguration = struct {
    keySystem: runtime.DOMString,
    initDataType: ?runtime.DOMString = null,
    distinctiveIdentifier: ?enums.MediaKeysRequirement = null,
    persistentState: ?enums.MediaKeysRequirement = null,
    sessionTypes: ?[]const runtime.DOMString = null,
    audio: ?KeySystemTrackConfiguration = null,
    video: ?KeySystemTrackConfiguration = null,
};
