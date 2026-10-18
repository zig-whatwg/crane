//! WebIDL dictionary: HashChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const HashChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    oldURL: ?runtime.USVString = null,
    newURL: ?runtime.USVString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "oldURL", .{ .string = "" } },
        .{ "newURL", .{ .string = "" } },
    };
};
