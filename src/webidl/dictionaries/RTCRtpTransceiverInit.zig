//! WebIDL dictionary: RTCRtpTransceiverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const RTCRtpEncodingParameters = @import("RTCRtpEncodingParameters.zig").RTCRtpEncodingParameters;

pub const RTCRtpTransceiverInit = struct {
    direction: ?enums.RTCRtpTransceiverDirection = null,
    streams: ?[]const *runtime.Instance = null,
    sendEncodings: ?[]const RTCRtpEncodingParameters = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "direction", .{ .string = "sendrecv" } },
        .{ "streams", .empty_sequence },
        .{ "sendEncodings", .empty_sequence },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "streams", "MediaStream" },
    };
};
