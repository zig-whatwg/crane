//! WebIDL dictionary: CharacterBoundsUpdateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CharacterBoundsUpdateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    rangeStart: ?u32 = null,
    rangeEnd: ?u32 = null,
};
