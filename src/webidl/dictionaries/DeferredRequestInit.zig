//! WebIDL dictionary: DeferredRequestInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RequestInit = @import("RequestInit.zig").RequestInit;

pub const DeferredRequestInit = struct {
    // Inherited from RequestInit
    base: RequestInit,

    activateAfter: ?anyopaque = null,
};
