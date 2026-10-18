//! WebIDL dictionary: FenceEvent
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const FenceEvent = struct {
    eventType: ?runtime.DOMString = null,
    eventData: ?runtime.DOMString = null,
    destination: ?[]const enums.FenceReportingDestination = null,
    crossOriginExposed: ?bool = null,
    once: ?bool = null,
    destinationURL: ?runtime.USVString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "crossOriginExposed", .{ .boolean = false } },
        .{ "once", .{ .boolean = false } },
    };
};
