//! WebIDL dictionary: CrashReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const CrashReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    reason: ?runtime.DOMString = null,
    stack: ?runtime.DOMString = null,
    is_top_level: ?bool = null,
    page_visibility: ?enums.DocumentVisibilityState = null,
};
