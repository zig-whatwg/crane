//! WebIDL dictionary: SecurityPolicyViolationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const SecurityPolicyViolationEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    documentURI: ?runtime.DOMString = null,
    referrer: ?runtime.DOMString = null,
    blockedURI: ?runtime.DOMString = null,
    violatedDirective: ?runtime.DOMString = null,
    effectiveDirective: ?runtime.DOMString = null,
    originalPolicy: ?runtime.DOMString = null,
    sourceFile: ?runtime.DOMString = null,
    sample: ?runtime.DOMString = null,
    disposition: ?anyopaque = null,
    statusCode: ?u16 = null,
    lineNumber: ?u32 = null,
    columnNumber: ?u32 = null,
};
