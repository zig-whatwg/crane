//! WebIDL dictionary: MessageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const MessageEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    data: ?anyopaque = null,
    origin: ?runtime.DOMString = null,
    lastEventId: ?runtime.DOMString = null,
    source: ?anyopaque = null,
    ports: ?anyopaque = null,
};
