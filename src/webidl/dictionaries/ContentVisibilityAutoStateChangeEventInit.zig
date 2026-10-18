//! WebIDL dictionary: ContentVisibilityAutoStateChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const ContentVisibilityAutoStateChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    skipped: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "skipped", .{ .boolean = false } },
    };
};
