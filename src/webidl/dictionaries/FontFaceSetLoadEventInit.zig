//! WebIDL dictionary: FontFaceSetLoadEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const FontFaceSetLoadEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    fontfaces: ?anyopaque = null,
};
