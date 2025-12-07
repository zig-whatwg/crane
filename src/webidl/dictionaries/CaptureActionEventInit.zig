//! WebIDL dictionary: CaptureActionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const CaptureActionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    action: ?runtime.DOMString = null,
};
