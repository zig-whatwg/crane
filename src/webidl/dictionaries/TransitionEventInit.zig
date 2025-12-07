//! WebIDL dictionary: TransitionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const TransitionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    propertyName: ?typedefs.CSSOMString = null,
    elapsedTime: ?f64 = null,
    pseudoElement: ?typedefs.CSSOMString = null,
};
