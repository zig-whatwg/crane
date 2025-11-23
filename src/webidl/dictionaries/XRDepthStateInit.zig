//! WebIDL dictionary: XRDepthStateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const XRDepthStateInit = struct {
    usagePreference: *const anyopaque,
    dataFormatPreference: *const anyopaque,
    depthTypeRequest: ?*const anyopaque = null,
    matchDepthView: ?bool = null,
};
