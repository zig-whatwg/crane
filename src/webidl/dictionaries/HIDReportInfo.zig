//! WebIDL dictionary: HIDReportInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const HIDReportItem = @import("HIDReportItem.zig").HIDReportItem;

pub const HIDReportInfo = struct {
    reportId: ?u8 = null,
    items: ?[]const HIDReportItem = null,
};
