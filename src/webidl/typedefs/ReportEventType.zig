//! WebIDL typedef: ReportEventType
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");

pub const ReportEventType = union(enum) {
    fence_event: *runtime.Instance,
    domstring: runtime.DOMString,
};
