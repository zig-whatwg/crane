//! WebIDL dictionary: MediaKeySystemConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaKeySystemConfiguration = struct {
    label: ?runtime.DOMString = null,
    initDataTypes: ?*const anyopaque = null,
    audioCapabilities: ?*const anyopaque = null,
    videoCapabilities: ?*const anyopaque = null,
    distinctiveIdentifier: ?*const anyopaque = null,
    persistentState: ?*const anyopaque = null,
    sessionTypes: ?*const anyopaque = null,
};
