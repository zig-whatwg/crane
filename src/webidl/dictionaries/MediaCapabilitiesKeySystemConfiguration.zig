//! WebIDL dictionary: MediaCapabilitiesKeySystemConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaCapabilitiesKeySystemConfiguration = struct {
    keySystem: runtime.DOMString,
    initDataType: ?runtime.DOMString = null,
    distinctiveIdentifier: ?*const anyopaque = null,
    persistentState: ?*const anyopaque = null,
    sessionTypes: ?*const anyopaque = null,
    audio: ?*const anyopaque = null,
    video: ?*const anyopaque = null,
};
