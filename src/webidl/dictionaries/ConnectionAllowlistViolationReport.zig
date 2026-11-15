//! WebIDL dictionary: ConnectionAllowlistViolationReport
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const ConnectionAllowlistViolationReport = struct {
    // Inherited from ReportBody
    base: ReportBody,

    url: ?runtime.USVString = null,
    connection: ?runtime.USVString = null,
    allowlist: ?[]const runtime.DOMString = null,
    disposition: ?enums.ConnectionAllowlistDisposition = null,
};
