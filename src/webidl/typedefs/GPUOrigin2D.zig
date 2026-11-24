//! WebIDL typedef: GPUOrigin2D
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const GPUOrigin2D = union(enum) {
    gpuinteger_coordinate_sequence: []const typedefs.GPUIntegerCoordinate,
    gpuorigin2ddict: dictionaries.GPUOrigin2DDict,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "gpuinteger_coordinate_sequence", .kind = .sequence },
        .{ .field = "gpuorigin2ddict", .kind = .dictionary },
    };
};
