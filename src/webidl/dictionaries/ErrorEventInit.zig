//! WebIDL dictionary: ErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const ErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    message: ?runtime.DOMString = null,
    filename: ?runtime.USVString = null,
    lineno: ?u32 = null,
    colno: ?u32 = null,
    @"error": ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"error"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "message", .{ .string = "" } },
        .{ "filename", .{ .string = "" } },
        .{ "lineno", .{ .number = 0 } },
        .{ "colno", .{ .number = 0 } },
    };
};
