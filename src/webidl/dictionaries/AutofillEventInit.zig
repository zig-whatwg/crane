//! WebIDL dictionary: AutofillEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const AutofillEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    autofillValues: ?[]const typedefs.AutofillValueEntry = null,
    allowRefill: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "autofillValues", .empty_sequence },
        .{ "allowRefill", .{ .boolean = true } },
    };
};
