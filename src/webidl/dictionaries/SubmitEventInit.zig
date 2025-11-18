//! WebIDL dictionary: SubmitEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const SubmitEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    submitter: ?anyopaque = null,
};
