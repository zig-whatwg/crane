//! WebIDL dictionary: ClipboardChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const ClipboardChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    types: ?[]const runtime.DOMString = null,
    changeId: ?runtime.JSValue = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "types", .empty_sequence },
        .{ "changeId", .{ .number = 0 } },
    };
};
