//! WebIDL dictionary: WebGLContextEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const WebGLContextEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    statusMessage: ?runtime.DOMString = null,
};
