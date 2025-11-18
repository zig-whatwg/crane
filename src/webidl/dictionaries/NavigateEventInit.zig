//! WebIDL dictionary: NavigateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const NavigateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    navigationType: ?anyopaque = null,
    destination: anyopaque,
    canIntercept: ?bool = null,
    userInitiated: ?bool = null,
    hashChange: ?bool = null,
    signal: anyopaque,
    formData: ?anyopaque = null,
    downloadRequest: ?anyopaque = null,
    info: ?anyopaque = null,
    hasUAVisualTransition: ?bool = null,
    sourceElement: ?anyopaque = null,
};
