//! WebIDL typedef: ConstrainPoint2D
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const ConstrainPoint2D = union(enum) {
    point2d_sequence: []const dictionaries.Point2D,
    constrain_point2dparameters: dictionaries.ConstrainPoint2DParameters,
};
