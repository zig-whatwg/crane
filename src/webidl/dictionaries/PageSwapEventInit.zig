//! WebIDL dictionary: PageSwapEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const PageSwapEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    activation: ?*runtime.Instance = null,
    viewTransition: ?*runtime.Instance = null,
};
