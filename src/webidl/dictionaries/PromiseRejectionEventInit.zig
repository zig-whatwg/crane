//! WebIDL dictionary: PromiseRejectionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const PromiseRejectionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    promise: v8.JSValue,
    reason: ?v8.JSValue = null,
};
