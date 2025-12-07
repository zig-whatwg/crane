//! WebIDL dictionary: ProgressEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const ProgressEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    lengthComputable: ?bool = null,
    loaded: ?f64 = null,
    total: ?f64 = null,
};
