//! WebIDL dictionary: RTCConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const RTCIceServer = @import("RTCIceServer.zig").RTCIceServer;

pub const RTCConfiguration = struct {
    iceServers: ?[]const RTCIceServer = null,
    iceTransportPolicy: ?enums.RTCIceTransportPolicy = null,
    bundlePolicy: ?enums.RTCBundlePolicy = null,
    rtcpMuxPolicy: ?enums.RTCRtcpMuxPolicy = null,
    certificates: ?[]const *runtime.Instance = null,
    iceCandidatePoolSize: ?u8 = null,
    peerIdentity: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "iceServers", .empty_sequence },
        .{ "iceTransportPolicy", .{ .string = "all" } },
        .{ "bundlePolicy", .{ .string = "balanced" } },
        .{ "rtcpMuxPolicy", .{ .string = "require" } },
        .{ "certificates", .empty_sequence },
        .{ "iceCandidatePoolSize", .{ .number = 0 } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"iceCandidatePoolSize"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "certificates", "RTCCertificate" },
    };
};
