//! WebIDL dictionary: IntegrityViolationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const IntegrityViolationReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    documentURL: ?runtime.USVString = null,
    blockedURL: ?runtime.USVString = null,
    destination: ?runtime.USVString = null,
    reportOnly: ?bool = null,
};
