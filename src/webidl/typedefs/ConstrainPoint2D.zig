//! WebIDL typedef: ConstrainPoint2D
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const ConstrainPoint2D = union(enum) {
    point2d_sequence: []const dictionaries.Point2D,
    constrain_point2dparameters: dictionaries.ConstrainPoint2DParameters,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "point2d_sequence", .kind = .{ .sequence = null } },
        .{ .field = "constrain_point2dparameters", .kind = .dictionary },
    };
};
