//! WebIDL dictionary: DetectedBarcode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const Point2D = @import("Point2D.zig").Point2D;

pub const DetectedBarcode = struct {
    boundingBox: *runtime.Instance,
    rawValue: runtime.DOMString,
    format: enums.BarcodeFormat,
    cornerPoints: []const Point2D,
};
