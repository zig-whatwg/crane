//! WebIDL dictionary: XRInputSourceEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRInputSourceEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    frame: *runtime.Instance,
    inputSource: *runtime.Instance,
};
