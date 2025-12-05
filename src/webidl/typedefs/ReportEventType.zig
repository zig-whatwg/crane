//! WebIDL typedef: ReportEventType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const ReportEventType = union(enum) {
    fence_event: dictionaries.FenceEvent,
    domstring: runtime.DOMString,
};
