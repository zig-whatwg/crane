//! WebIDL dictionary: PromiseRejectionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const PromiseRejectionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    promise: runtime.JSValue,
    reason: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"reason"};
};
