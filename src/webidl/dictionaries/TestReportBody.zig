//! WebIDL dictionary: TestReportBody
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const TestReportBody = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from ReportBody
    base: ReportBody,

    message: ?runtime.DOMString = null,
};
