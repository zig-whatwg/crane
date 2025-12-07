//! WebIDL dictionary: MediaKeySystemConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const MediaKeySystemMediaCapability = @import("MediaKeySystemMediaCapability.zig").MediaKeySystemMediaCapability;

pub const MediaKeySystemConfiguration = struct {
    label: ?runtime.DOMString = null,
    initDataTypes: ?[]const runtime.DOMString = null,
    audioCapabilities: ?[]const MediaKeySystemMediaCapability = null,
    videoCapabilities: ?[]const MediaKeySystemMediaCapability = null,
    distinctiveIdentifier: ?enums.MediaKeysRequirement = null,
    persistentState: ?enums.MediaKeysRequirement = null,
    sessionTypes: ?[]const runtime.DOMString = null,
};
