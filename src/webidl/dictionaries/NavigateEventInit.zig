//! WebIDL dictionary: NavigateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const NavigateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    navigationType: ?enums.NavigationType = null,
    destination: *runtime.Instance,
    canIntercept: ?bool = null,
    userInitiated: ?bool = null,
    hashChange: ?bool = null,
    signal: *runtime.Instance,
    formData: ?*runtime.Instance = null,
    downloadRequest: ?runtime.DOMString = null,
    info: ?runtime.JSValue = null,
    hasUAVisualTransition: ?bool = null,
    sourceElement: ?*runtime.Instance = null,
};
