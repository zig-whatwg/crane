//! WebIDL dictionary: RTCDataChannelInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const RTCDataChannelInit = struct {
    ordered: ?bool = null,
    maxPacketLifeTime: ?u16 = null,
    maxRetransmits: ?u16 = null,
    protocol: ?runtime.USVString = null,
    negotiated: ?bool = null,
    id: ?u16 = null,
    priority: ?enums.RTCPriorityType = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "ordered", .{ .boolean = true } },
        .{ "protocol", .{ .string = "" } },
        .{ "negotiated", .{ .boolean = false } },
        .{ "priority", .{ .string = "low" } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "maxPacketLifeTime", "maxRetransmits", "id" };
};
