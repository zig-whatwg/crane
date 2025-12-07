//! WebIDL dictionary: CapturedMouseEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const CapturedMouseEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    surfaceX: ?i32 = null,
    surfaceY: ?i32 = null,
};
