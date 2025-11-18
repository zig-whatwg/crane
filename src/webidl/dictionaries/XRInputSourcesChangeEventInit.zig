//! WebIDL dictionary: XRInputSourcesChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRInputSourcesChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    session: anyopaque,
    added: anyopaque,
    removed: anyopaque,
};
