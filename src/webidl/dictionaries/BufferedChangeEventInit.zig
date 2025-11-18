//! WebIDL dictionary: BufferedChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const BufferedChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    addedRanges: ?anyopaque = null,
    removedRanges: ?anyopaque = null,
};
