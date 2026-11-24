//! WebIDL typedef: GPUTextureViewDimensionOrUndefined
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const enums = @import("enums");

pub const GPUTextureViewDimensionOrUndefined = union(enum) {
    gputexture_view_dimension: enums.GPUTextureViewDimension,
    undefined: void,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "gputexture_view_dimension", .kind = .enumeration },
        .{ .field = "undefined", .kind = .undefined },
    };
};
