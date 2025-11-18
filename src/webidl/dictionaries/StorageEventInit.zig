//! WebIDL dictionary: StorageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const StorageEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    key: ?anyopaque = null,
    oldValue: ?anyopaque = null,
    newValue: ?anyopaque = null,
    url: ?runtime.DOMString = null,
    storageArea: ?anyopaque = null,
};
