//! WebIDL dictionary: DeprecationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const DeprecationReportBody = struct {
    // Inherited from ReportBody
    base: ReportBody,

    id: ?runtime.DOMString = null,
    anticipatedRemoval: ?runtime.JSValue = null,
    message: ?runtime.DOMString = null,
    sourceFile: ?runtime.DOMString = null,
    lineNumber: ?u32 = null,
    columnNumber: ?u32 = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "anticipatedRemoval", "sourceFile", "lineNumber", "columnNumber" };
};
