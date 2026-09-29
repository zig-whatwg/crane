//! WebIDL dictionary: CustomEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CustomEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    detail: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"detail"};
};
