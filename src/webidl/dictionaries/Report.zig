//! WebIDL dictionary: Report
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ReportBody = @import("ReportBody.zig").ReportBody;

pub const Report = struct {
    @"type": ?runtime.DOMString = null,
    url: ?runtime.DOMString = null,
    body: ?ReportBody = null,
};
