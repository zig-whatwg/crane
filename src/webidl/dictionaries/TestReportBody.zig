//! WebIDL dictionary: TestReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const TestReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    message: ?runtime.DOMString = null,
};
