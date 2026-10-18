//! WebIDL dictionary: TextUpdateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const TextUpdateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    updateRangeStart: ?u32 = null,
    updateRangeEnd: ?u32 = null,
    text: ?runtime.DOMString = null,
    selectionStart: ?u32 = null,
    selectionEnd: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "updateRangeStart", .{ .number = 0 } },
        .{ "updateRangeEnd", .{ .number = 0 } },
        .{ "text", .{ .string = "" } },
        .{ "selectionStart", .{ .number = 0 } },
        .{ "selectionEnd", .{ .number = 0 } },
    };
};
