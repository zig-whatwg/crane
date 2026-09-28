//! WebIDL dictionary: DoubleRange
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DoubleRange = struct {
    max: ?f64 = null,
    min: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "max", "min" };
};
