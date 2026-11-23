//! WebIDL dictionary: CloseEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CloseEventInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from EventInit
    base: EventInit,

    wasClean: ?bool = null,
    code: ?u16 = null,
    reason: ?runtime.USVString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "wasClean", .{ .boolean = false } },
        .{ "code", .{ .number = 0 } },
        .{ "reason", .{ .string = "" } },
    };
};
