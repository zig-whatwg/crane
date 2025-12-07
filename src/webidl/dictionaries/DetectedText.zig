//! WebIDL dictionary: DetectedText
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Point2D = @import("Point2D.zig").Point2D;

pub const DetectedText = struct {
    boundingBox: *runtime.Instance,
    rawValue: runtime.DOMString,
    cornerPoints: []const Point2D,
};
