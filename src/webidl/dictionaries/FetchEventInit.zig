//! WebIDL dictionary: FetchEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const FetchEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    request: *runtime.Instance,
    preloadResponse: ?*const anyopaque = null,
    clientId: ?runtime.DOMString = null,
    resultingClientId: ?runtime.DOMString = null,
    replacesClientId: ?runtime.DOMString = null,
    handled: ?*const anyopaque = null,
};
