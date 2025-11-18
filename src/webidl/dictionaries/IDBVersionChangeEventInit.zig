//! WebIDL dictionary: IDBVersionChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const IDBVersionChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    oldVersion: ?u64 = null,
    newVersion: ?anyopaque = null,
};
