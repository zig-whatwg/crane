//! WebIDL dictionary: BufferedChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const BufferedChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    addedRanges: ?*runtime.Instance = null,
    removedRanges: ?*runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "addedRanges", "TimeRanges" },
        .{ "removedRanges", "TimeRanges" },
    };
};
