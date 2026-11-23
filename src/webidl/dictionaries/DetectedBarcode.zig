//! WebIDL dictionary: DetectedBarcode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const Point2D = @import("Point2D.zig").Point2D;

pub const DetectedBarcode = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    boundingBox: *runtime.Instance,
    rawValue: runtime.DOMString,
    format: enums.BarcodeFormat,
    cornerPoints: []const Point2D,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "boundingBox", "DOMRectReadOnly" },
    };
};
