//! WebIDL dictionary: RTCDTMFToneChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const RTCDTMFToneChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    tone: ?runtime.DOMString = null,
};
