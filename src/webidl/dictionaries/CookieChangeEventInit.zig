//! WebIDL dictionary: CookieChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const CookieChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    changed: ?typedefs.CookieList = null,
    deleted: ?typedefs.CookieList = null,
};
