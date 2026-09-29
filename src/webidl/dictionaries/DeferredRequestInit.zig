//! WebIDL dictionary: DeferredRequestInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const RequestInit = @import("RequestInit.zig").RequestInit;

pub const DeferredRequestInit = struct {
    // Inherited from RequestInit
    base: RequestInit,

    activateAfter: ?typedefs.DOMHighResTimeStamp = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"activateAfter"};
};
