//! WebIDL dictionary: ToggleEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const ToggleEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    oldState: ?runtime.DOMString = null,
    newState: ?runtime.DOMString = null,
    source: ?*runtime.Instance = null,
};
