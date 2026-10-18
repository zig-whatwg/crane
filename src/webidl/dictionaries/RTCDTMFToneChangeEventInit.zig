//! WebIDL dictionary: RTCDTMFToneChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const RTCDTMFToneChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    tone: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "tone", .{ .string = "" } },
    };
};
