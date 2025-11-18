//! WebIDL dictionary: ExtendableMessageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const ExtendableMessageEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    data: ?anyopaque = null,
    origin: ?runtime.DOMString = null,
    lastEventId: ?runtime.DOMString = null,
    source: ?anyopaque = null,
    ports: ?anyopaque = null,
};
