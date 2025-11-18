//! WebIDL dictionary: CookieChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CookieChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    changed: ?anyopaque = null,
    deleted: ?anyopaque = null,
};
