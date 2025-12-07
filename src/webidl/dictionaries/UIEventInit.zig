//! WebIDL dictionary: UIEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const UIEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    view: ?*runtime.Instance = null,
    detail: ?i32 = null,
    which: ?u32 = null,
    sourceCapabilities: ?*runtime.Instance = null,
};
