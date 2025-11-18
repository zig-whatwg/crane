//! WebIDL dictionary: CloseEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CloseEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    wasClean: ?bool = null,
    code: ?u16 = null,
    reason: ?runtime.DOMString = null,
};
