//! WebIDL dictionary: CSPViolationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const CSPViolationReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    documentURL: ?runtime.DOMString = null,
    referrer: ?anyopaque = null,
    blockedURL: ?anyopaque = null,
    effectiveDirective: ?runtime.DOMString = null,
    originalPolicy: ?runtime.DOMString = null,
    sourceFile: ?anyopaque = null,
    sample: ?anyopaque = null,
    disposition: ?anyopaque = null,
    statusCode: ?u16 = null,
    lineNumber: ?anyopaque = null,
    columnNumber: ?anyopaque = null,
};
