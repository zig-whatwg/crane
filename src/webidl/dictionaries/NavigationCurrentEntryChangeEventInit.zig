//! WebIDL dictionary: NavigationCurrentEntryChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const NavigationCurrentEntryChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    navigationType: ?anyopaque = null,
    from: anyopaque,
};
