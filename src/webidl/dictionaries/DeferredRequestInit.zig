//! WebIDL dictionary: DeferredRequestInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const RequestInit = @import("RequestInit.zig").RequestInit;

pub const DeferredRequestInit = struct {
    // Inherited from RequestInit
    base: RequestInit,

    activateAfter: ?typedefs.DOMHighResTimeStamp = null,
};
