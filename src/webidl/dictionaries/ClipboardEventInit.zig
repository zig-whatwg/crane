//! WebIDL dictionary: ClipboardEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const ClipboardEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    clipboardData: ?anyopaque = null,
};
