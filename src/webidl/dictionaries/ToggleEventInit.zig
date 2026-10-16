//! WebIDL dictionary: ToggleEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const ToggleEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    oldState: ?runtime.DOMString = null,
    newState: ?runtime.DOMString = null,
    source: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"source"};
};
