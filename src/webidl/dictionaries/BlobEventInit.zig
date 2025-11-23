//! WebIDL dictionary: BlobEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const BlobEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    data: *const anyopaque,
    timecode: ?*const anyopaque = null,
};
