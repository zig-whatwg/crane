//! WebIDL dictionary: Report
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const Report = struct {
    type: ?runtime.DOMString = null,
    url: ?runtime.DOMString = null,
    body: ?ReportBody = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"body"};
};
