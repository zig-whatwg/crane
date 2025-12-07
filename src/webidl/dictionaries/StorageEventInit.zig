//! WebIDL dictionary: StorageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const StorageEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    key: ?runtime.DOMString = null,
    oldValue: ?runtime.DOMString = null,
    newValue: ?runtime.DOMString = null,
    url: ?runtime.USVString = null,
    storageArea: ?*runtime.Instance = null,
};
