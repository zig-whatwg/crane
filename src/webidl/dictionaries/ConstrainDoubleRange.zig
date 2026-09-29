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

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "exact", "ideal" };
};
