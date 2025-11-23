//! WebIDL dictionary: XRReferenceSpaceEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRReferenceSpaceEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    referenceSpace: *const anyopaque,
    transform: ?*const anyopaque = null,
};
