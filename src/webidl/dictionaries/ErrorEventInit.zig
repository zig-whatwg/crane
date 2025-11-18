//! WebIDL dictionary: ErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const ErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    message: ?runtime.DOMString = null,
    filename: ?runtime.DOMString = null,
    lineno: ?u32 = null,
    colno: ?u32 = null,
    error: ?anyopaque = null,
};
