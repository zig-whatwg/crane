//! WebIDL dictionary: KeyboardEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventModifierInit = @import("EventModifierInit.zig").EventModifierInit;

pub const KeyboardEventInit = struct {
    // Inherited from EventModifierInit
    base: EventModifierInit,

    key: ?runtime.DOMString = null,
    code: ?runtime.DOMString = null,
    location: ?u32 = null,
    repeat: ?bool = null,
    isComposing: ?bool = null,
    charCode: ?u32 = null,
    keyCode: ?u32 = null,
};
