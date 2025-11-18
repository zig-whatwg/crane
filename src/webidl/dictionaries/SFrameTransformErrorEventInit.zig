//! WebIDL dictionary: SFrameTransformErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const SFrameTransformErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    errorType: anyopaque,
    frame: anyopaque,
    keyID: ?anyopaque = null,
};
