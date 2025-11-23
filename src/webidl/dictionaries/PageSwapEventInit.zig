//! WebIDL dictionary: PageSwapEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const PageSwapEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    activation: ?*const anyopaque = null,
    viewTransition: ?*const anyopaque = null,
};
