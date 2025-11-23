//! WebIDL dictionary: DetectedBarcode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const DetectedBarcode = struct {
    boundingBox: *const anyopaque,
    rawValue: runtime.DOMString,
    format: *const anyopaque,
    cornerPoints: *const anyopaque,
};
