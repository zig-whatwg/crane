//! WebIDL dictionary: XRDepthStateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const XRDepthStateInit = struct {
    usagePreference: anyopaque,
    dataFormatPreference: anyopaque,
    depthTypeRequest: ?anyopaque = null,
    matchDepthView: ?bool = null,
};
