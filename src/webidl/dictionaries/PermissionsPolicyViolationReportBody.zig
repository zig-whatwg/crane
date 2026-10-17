//! WebIDL dictionary: PermissionsPolicyViolationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const PermissionsPolicyViolationReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    featureId: ?runtime.DOMString = null,
    sourceFile: ?runtime.DOMString = null,
    lineNumber: ?i32 = null,
    columnNumber: ?i32 = null,
    disposition: ?runtime.DOMString = null,
    allowAttribute: ?runtime.DOMString = null,
    srcAttribute: ?runtime.DOMString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "sourceFile", "lineNumber", "columnNumber", "allowAttribute", "srcAttribute" };
};
