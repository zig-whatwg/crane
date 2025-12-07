//! WebIDL dictionary: PortalActivateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const PortalActivateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    data: ?v8.JSValue = null,
};
