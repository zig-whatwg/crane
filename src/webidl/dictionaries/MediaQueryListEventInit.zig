//! WebIDL dictionary: MediaQueryListEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const MediaQueryListEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    media: ?anyopaque = null,
    matches: ?bool = null,
};
