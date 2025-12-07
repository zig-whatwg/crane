//! WebIDL dictionary: CommandEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const CommandEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    source: ?*runtime.Instance = null,
    command: ?runtime.DOMString = null,
};
