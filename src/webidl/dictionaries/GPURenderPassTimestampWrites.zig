//! WebIDL dictionary: GPURenderPassTimestampWrites
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const GPURenderPassTimestampWrites = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    querySet: *runtime.Instance,
    beginningOfPassWriteIndex: ?typedefs.GPUSize32 = null,
    endOfPassWriteIndex: ?typedefs.GPUSize32 = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "querySet", "GPUQuerySet" },
    };
};
