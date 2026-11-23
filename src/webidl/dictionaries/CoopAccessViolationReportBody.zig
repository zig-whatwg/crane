//! WebIDL dictionary: CoopAccessViolationReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const CoopAccessViolationReportBody = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from ReportBody
    base: ReportBody,

    sourceFile: ?runtime.DOMString = null,
    lineNumber: ?u32 = null,
    columnNumber: ?u32 = null,
    type: ?runtime.DOMString = null,
    property: ?runtime.DOMString = null,
    openeeURL: ?runtime.DOMString = null,
    openerURL: ?runtime.DOMString = null,
    otherDocumentURL: ?runtime.DOMString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "sourceFile", "lineNumber", "columnNumber" };
};
