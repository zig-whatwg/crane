//! WebIDL dictionary: RTCIceGatherOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const RTCIceServer = @import("RTCIceServer.zig").RTCIceServer;

pub const RTCIceGatherOptions = struct {
    gatherPolicy: ?enums.RTCIceTransportPolicy = null,
    iceServers: ?[]const RTCIceServer = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "gatherPolicy", .{ .string = "all" } },
    };
};
