//! WebIDL dictionary: ExtendableMessageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const ExtendableMessageEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    data: ?v8.JSValue = null,
    origin: ?runtime.USVString = null,
    lastEventId: ?runtime.DOMString = null,
    source: ?*const anyopaque = null,
    ports: ?[]const *runtime.Instance = null,
};
