//! WebIDL dictionary: PAHistogramContribution
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PAHistogramContribution = struct {
    bucket: *const anyopaque,
    value: i32,
    filteringId: ?*const anyopaque = null,
};
