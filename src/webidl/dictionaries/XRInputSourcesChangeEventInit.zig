//! WebIDL dictionary: XRInputSourcesChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRInputSourcesChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    session: *runtime.Instance,
    added: []const *runtime.Instance,
    removed: []const *runtime.Instance,
};
