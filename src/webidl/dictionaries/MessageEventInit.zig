//! WebIDL dictionary: MessageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const MessageEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    data: ?*const anyopaque = null,
    origin: ?runtime.USVString = null,
    lastEventId: ?runtime.DOMString = null,
    source: ?*const anyopaque = null,
    ports: ?*const anyopaque = null,
};
