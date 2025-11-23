//! WebIDL dictionary: ConstrainDoubleRange
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const DoubleRange = @import("DoubleRange.zig").DoubleRange;

pub const ConstrainDoubleRange = struct {
    // Inherited from DoubleRange
    base: DoubleRange,

    exact: ?f64 = null,
    ideal: ?f64 = null,
};
