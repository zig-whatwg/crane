//! WebIDL dictionary: PageRevealEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const PageRevealEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    viewTransition: ?anyopaque = null,
};
