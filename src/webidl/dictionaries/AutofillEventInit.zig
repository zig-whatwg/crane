//! WebIDL dictionary: AutofillEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const AutofillEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    autofillValues: ?[]const typedefs.AutofillValueEntry = null,
    allowRefill: ?bool = null,
};
