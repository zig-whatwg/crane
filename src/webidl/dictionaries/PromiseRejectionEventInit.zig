//! WebIDL dictionary: PromiseRejectionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const PromiseRejectionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    promise: anyopaque,
    reason: ?anyopaque = null,
};
