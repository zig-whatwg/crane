//! WebIDL dictionary: CSPViolationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const CSPViolationReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    documentURL: ?runtime.DOMString = null,
    referrer: ?runtime.DOMString = null,
    blockedURL: ?runtime.DOMString = null,
    effectiveDirective: ?runtime.DOMString = null,
    originalPolicy: ?runtime.DOMString = null,
    sourceFile: ?runtime.DOMString = null,
    sample: ?runtime.DOMString = null,
    disposition: ?anyopaque = null,
    statusCode: ?u16 = null,
    lineNumber: ?u32 = null,
    columnNumber: ?u32 = null,
};
