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

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"promise"};

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"reason"};
};
