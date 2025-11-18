//! WebIDL dictionary: HashChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const HashChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    oldURL: ?runtime.DOMString = null,
    newURL: ?runtime.DOMString = null,
};
