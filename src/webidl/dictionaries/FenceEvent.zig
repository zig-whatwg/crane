//! WebIDL dictionary: FenceEvent
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const FenceEvent = struct {
    eventType: ?runtime.DOMString = null,
    eventData: ?runtime.DOMString = null,
    destination: ?[]const enums.FenceReportingDestination = null,
    crossOriginExposed: ?bool = null,
    once: ?bool = null,
    destinationURL: ?runtime.USVString = null,
};
