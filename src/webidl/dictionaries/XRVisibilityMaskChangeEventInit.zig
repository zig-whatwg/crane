//! WebIDL dictionary: XRVisibilityMaskChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRVisibilityMaskChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    session: anyopaque,
    eye: anyopaque,
    index: u32,
    vertices: anyopaque,
    indices: anyopaque,
};
