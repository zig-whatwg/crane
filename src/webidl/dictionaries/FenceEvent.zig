//! WebIDL dictionary: FenceEvent
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FenceEvent = struct {
    eventType: ?runtime.DOMString = null,
    eventData: ?runtime.DOMString = null,
    destination: ?anyopaque = null,
    crossOriginExposed: ?bool = null,
    once: ?bool = null,
    destinationURL: ?runtime.DOMString = null,
};
