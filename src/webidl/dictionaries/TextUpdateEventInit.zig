//! WebIDL dictionary: TextUpdateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const TextUpdateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    updateRangeStart: ?u32 = null,
    updateRangeEnd: ?u32 = null,
    text: ?runtime.DOMString = null,
    selectionStart: ?u32 = null,
    selectionEnd: ?u32 = null,
    compositionStart: ?u32 = null,
    compositionEnd: ?u32 = null,
};
