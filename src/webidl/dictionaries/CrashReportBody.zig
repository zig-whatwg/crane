//! WebIDL dictionary: CrashReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const CrashReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    reason: ?runtime.DOMString = null,
    stack: ?runtime.DOMString = null,
    is_top_level: ?bool = null,
    visibility_state: ?enums.DocumentVisibilityState = null,
    crash_report_api: ?runtime.JSValue = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"crash_report_api"};
};
