//! WebIDL dictionary: FetchEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const FetchEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    request: anyopaque,
    preloadResponse: ?anyopaque = null,
    clientId: ?runtime.DOMString = null,
    resultingClientId: ?runtime.DOMString = null,
    replacesClientId: ?runtime.DOMString = null,
    handled: ?anyopaque = null,
};
