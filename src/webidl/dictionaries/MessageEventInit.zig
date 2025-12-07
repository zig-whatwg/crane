//! WebIDL dictionary: MessageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const MessageEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    data: ?v8.JSValue = null,
    origin: ?runtime.USVString = null,
    lastEventId: ?runtime.DOMString = null,
    source: ?typedefs.MessageEventSource = null,
    ports: ?[]const *runtime.Instance = null,
};
