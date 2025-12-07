//! WebIDL dictionary: PAExtendedHistogramContribution
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PASignalValue = @import("PASignalValue.zig").PASignalValue;

pub const PAExtendedHistogramContribution = struct {
    bucket: *const anyopaque,
    value: *const anyopaque,
    filteringId: ?*const anyopaque = null,
};
