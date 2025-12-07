//! WebIDL dictionary: MediaKeyMessageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const MediaKeyMessageEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    messageType: enums.MediaKeyMessageType,
    message: *const anyopaque,
};
