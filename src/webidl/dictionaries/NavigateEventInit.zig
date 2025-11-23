//! WebIDL dictionary: NavigateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const NavigateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    navigationType: ?*const anyopaque = null,
    destination: *const anyopaque,
    canIntercept: ?bool = null,
    userInitiated: ?bool = null,
    hashChange: ?bool = null,
    signal: *const anyopaque,
    formData: ?*const anyopaque = null,
    downloadRequest: ?runtime.DOMString = null,
    info: ?*const anyopaque = null,
    hasUAVisualTransition: ?bool = null,
    sourceElement: ?*const anyopaque = null,
};
