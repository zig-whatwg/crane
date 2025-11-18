//! WebIDL dictionary: CustomEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CustomEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    detail: ?anyopaque = null,
};
