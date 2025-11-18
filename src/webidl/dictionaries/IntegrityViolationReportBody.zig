//! WebIDL dictionary: IntegrityViolationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const IntegrityViolationReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    documentURL: ?runtime.DOMString = null,
    blockedURL: ?runtime.DOMString = null,
    destination: ?runtime.DOMString = null,
    reportOnly: ?bool = null,
};
