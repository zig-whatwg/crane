//! WebIDL dictionary: ScriptingPolicyReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const ScriptingPolicyReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    violationType: ?runtime.DOMString = null,
    violationURL: ?runtime.USVString = null,
    violationSample: ?runtime.USVString = null,
    lineno: ?u32 = null,
    colno: ?u32 = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "violationURL", "violationSample" };
};
