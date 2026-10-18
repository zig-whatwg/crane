//! WebIDL dictionary: MediaQueryListEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const MediaQueryListEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    media: ?typedefs.CSSOMString = null,
    matches: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "media", .{ .string = "" } },
        .{ "matches", .{ .boolean = false } },
    };
};
