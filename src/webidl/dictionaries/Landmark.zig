//! WebIDL dictionary: Landmark
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const Point2D = @import("Point2D.zig").Point2D;

pub const Landmark = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    locations: []const Point2D,
    type: ?enums.LandmarkType = null,
};
