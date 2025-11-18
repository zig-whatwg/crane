//! WebIDL dictionary: MediaEncryptedEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const MediaEncryptedEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    initDataType: ?runtime.DOMString = null,
    initData: ?anyopaque = null,
};
