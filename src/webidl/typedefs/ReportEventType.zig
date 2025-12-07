//! WebIDL typedef: ReportEventType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const ReportEventType = union(enum) {
    fence_event: dictionaries.FenceEvent,
    domstring: runtime.DOMString,
};
