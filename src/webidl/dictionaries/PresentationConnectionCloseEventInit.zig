//! WebIDL dictionary: PresentationConnectionCloseEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const PresentationConnectionCloseEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    reason: enums.PresentationConnectionCloseReason,
    message: ?runtime.DOMString = null,
};
