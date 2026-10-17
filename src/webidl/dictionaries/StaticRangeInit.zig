//! WebIDL dictionary: StaticRangeInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const StaticRangeInit = struct {
    startContainer: *runtime.Instance,
    startOffset: u32,
    endContainer: *runtime.Instance,
    endOffset: u32,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "startContainer", "Node" },
        .{ "endContainer", "Node" },
    };
};
