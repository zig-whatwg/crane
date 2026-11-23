//! WebIDL typedef: GPUSize64OrUndefined
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const GPUSize64OrUndefined = union(enum) {
    gpusize64: typedefs.GPUSize64,
    undefined: void,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "gpusize64", .kind = .numeric },
        .{ .field = "undefined", .kind = .undefined },
    };
};
