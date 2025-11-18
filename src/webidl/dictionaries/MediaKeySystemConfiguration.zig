//! WebIDL dictionary: MediaKeySystemConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaKeySystemConfiguration = struct {
    label: ?runtime.DOMString = null,
    initDataTypes: ?anyopaque = null,
    audioCapabilities: ?anyopaque = null,
    videoCapabilities: ?anyopaque = null,
    distinctiveIdentifier: ?anyopaque = null,
    persistentState: ?anyopaque = null,
    sessionTypes: ?anyopaque = null,
};
