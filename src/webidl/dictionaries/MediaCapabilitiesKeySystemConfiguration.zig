//! WebIDL dictionary: MediaCapabilitiesKeySystemConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaCapabilitiesKeySystemConfiguration = struct {
    keySystem: runtime.DOMString,
    initDataType: ?runtime.DOMString = null,
    distinctiveIdentifier: ?anyopaque = null,
    persistentState: ?anyopaque = null,
    sessionTypes: ?anyopaque = null,
    audio: ?anyopaque = null,
    video: ?anyopaque = null,
};
