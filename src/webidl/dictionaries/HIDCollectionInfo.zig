//! WebIDL dictionary: HIDCollectionInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const HIDReportInfo = @import("HIDReportInfo.zig").HIDReportInfo;

pub const HIDCollectionInfo = struct {
    usagePage: ?u16 = null,
    usage: ?u16 = null,
    @"type": ?u8 = null,
    children: ?[]const HIDCollectionInfo = null,
    inputReports: ?[]const HIDReportInfo = null,
    outputReports: ?[]const HIDReportInfo = null,
    featureReports: ?[]const HIDReportInfo = null,
};
