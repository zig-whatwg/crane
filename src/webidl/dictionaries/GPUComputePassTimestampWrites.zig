//! WebIDL dictionary: GPUComputePassTimestampWrites
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPUComputePassTimestampWrites = struct {
    querySet: *runtime.Instance,
    beginningOfPassWriteIndex: ?typedefs.GPUSize32 = null,
    endOfPassWriteIndex: ?typedefs.GPUSize32 = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "querySet", "GPUQuerySet" },
    };
};
