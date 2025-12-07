//! WebIDL dictionary: CSPViolationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const CSPViolationReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    documentURL: ?runtime.USVString = null,
    referrer: ?runtime.USVString = null,
    blockedURL: ?runtime.USVString = null,
    effectiveDirective: ?runtime.DOMString = null,
    originalPolicy: ?runtime.DOMString = null,
    sourceFile: ?runtime.USVString = null,
    sample: ?runtime.DOMString = null,
    disposition: ?enums.SecurityPolicyViolationEventDisposition = null,
    statusCode: ?u16 = null,
    lineNumber: ?u32 = null,
    columnNumber: ?u32 = null,
};
