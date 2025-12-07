//! WebIDL dictionary: SecurityPolicyViolationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const SecurityPolicyViolationEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    documentURI: ?runtime.USVString = null,
    referrer: ?runtime.USVString = null,
    blockedURI: ?runtime.USVString = null,
    violatedDirective: ?runtime.DOMString = null,
    effectiveDirective: ?runtime.DOMString = null,
    originalPolicy: ?runtime.DOMString = null,
    sourceFile: ?runtime.USVString = null,
    sample: ?runtime.DOMString = null,
    disposition: ?enums.SecurityPolicyViolationEventDisposition = null,
    statusCode: ?u16 = null,
    lineNumber: ?u32 = null,
    columnNumber: ?u32 = null,
};
