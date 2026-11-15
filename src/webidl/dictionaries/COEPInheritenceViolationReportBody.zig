//! WebIDL dictionary: COEPInheritenceViolationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const COEPInheritenceViolationReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    type: ?runtime.DOMString = null,
    blockedURL: ?runtime.USVString = null,
    disposition: ?runtime.DOMString = null,
};
