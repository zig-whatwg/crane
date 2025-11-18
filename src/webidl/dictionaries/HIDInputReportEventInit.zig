//! WebIDL dictionary: HIDInputReportEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const HIDInputReportEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    device: anyopaque,
    reportId: u8,
    data: anyopaque,
};
