//! WebIDL dictionary: SnapEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const SnapEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    snapTargetBlock: ?*runtime.Instance = null,
    snapTargetInline: ?*runtime.Instance = null,
};
