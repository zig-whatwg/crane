//! WebIDL dictionary: ClipboardChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const ClipboardChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    types: ?[]const runtime.DOMString = null,
    changeId: ?runtime.JSValue = null,
};
