//! WebIDL dictionary: NDEFReadingEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const NDEFReadingEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    serialNumber: ?anyopaque = null,
    message: anyopaque,
};
