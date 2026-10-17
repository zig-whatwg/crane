//! WebIDL dictionary: Segment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const DOMRectInit = @import("DOMRectInit.zig").DOMRectInit;
const Point2D = @import("Point2D.zig").Point2D;

pub const Segment = struct {
    type: enums.SegmentType,
    id: i32,
    partOf: ?i32 = null,
    probability: f32,
    centerPoint: ?Point2D = null,
    boundingBox: ?DOMRectInit = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"probability"};
};
