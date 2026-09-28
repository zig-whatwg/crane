//! WebIDL dictionary: Point2D
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const Point2D = struct {
    x: ?f64 = null,
    y: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "x", "y" };
};
