//! WebIDL dictionary: SnapEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const SnapEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    snapTargetBlock: ?anyopaque = null,
    snapTargetInline: ?anyopaque = null,
};
