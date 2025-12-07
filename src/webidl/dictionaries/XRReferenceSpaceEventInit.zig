//! WebIDL dictionary: XRReferenceSpaceEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRReferenceSpaceEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    referenceSpace: *runtime.Instance,
    transform: ?*runtime.Instance = null,
};
