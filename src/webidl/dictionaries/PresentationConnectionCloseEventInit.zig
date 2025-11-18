//! WebIDL dictionary: PresentationConnectionCloseEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const PresentationConnectionCloseEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    reason: anyopaque,
    message: ?runtime.DOMString = null,
};
