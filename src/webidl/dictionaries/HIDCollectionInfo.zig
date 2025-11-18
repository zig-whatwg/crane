//! WebIDL dictionary: HIDCollectionInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HIDCollectionInfo = struct {
    usagePage: ?u16 = null,
    usage: ?u16 = null,
    type: ?u8 = null,
    children: ?anyopaque = null,
    inputReports: ?anyopaque = null,
    outputReports: ?anyopaque = null,
    featureReports: ?anyopaque = null,
};
