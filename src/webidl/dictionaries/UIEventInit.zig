//! WebIDL dictionary: UIEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const UIEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    view: ?*runtime.Instance = null,
    detail: ?i32 = null,
    sourceCapabilities: ?*runtime.Instance = null,
    which: ?u32 = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "view", "sourceCapabilities" };
};
