//! WebIDL dictionary: BlobEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const BlobEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    data: *runtime.Instance,
    timecode: ?typedefs.DOMHighResTimeStamp = null,
};
