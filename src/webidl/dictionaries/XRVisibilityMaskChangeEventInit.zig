//! WebIDL dictionary: XRVisibilityMaskChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRVisibilityMaskChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    session: *runtime.Instance,
    eye: enums.XREye,
    index: u32,
    vertices: *const anyopaque,
    indices: *const anyopaque,
};
