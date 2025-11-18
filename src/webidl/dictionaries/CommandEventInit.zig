//! WebIDL dictionary: CommandEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CommandEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    source: ?anyopaque = null,
    command: ?runtime.DOMString = null,
};
