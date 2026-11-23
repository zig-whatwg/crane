//! WebIDL dictionary: ConstrainPoint2DParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Point2D = @import("Point2D.zig").Point2D;

pub const ConstrainPoint2DParameters = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    exact: ?[]const Point2D = null,
    ideal: ?[]const Point2D = null,
};
