//! WebIDL dictionary: PresentationConnectionCloseEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const PresentationConnectionCloseEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    reason: enums.PresentationConnectionCloseReason,
    message: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "message", .{ .string = "" } },
    };
};
