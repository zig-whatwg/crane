//! WebIDL dictionary: HIDCollectionInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HIDCollectionInfo = struct {
    usagePage: ?u16 = null,
    usage: ?u16 = null,
    @"type": ?u8 = null,
    children: ?*const anyopaque = null,
    inputReports: ?*const anyopaque = null,
    outputReports: ?*const anyopaque = null,
    featureReports: ?*const anyopaque = null,
};
