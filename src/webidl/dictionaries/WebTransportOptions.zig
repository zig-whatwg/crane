//! WebIDL dictionary: WebTransportOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const WebTransportHash = @import("WebTransportHash.zig").WebTransportHash;

pub const WebTransportOptions = struct {
    allowPooling: ?bool = null,
    requireUnreliable: ?bool = null,
    headers: ?typedefs.HeadersInit = null,
    serverCertificateHashes: ?[]const WebTransportHash = null,
    congestionControl: ?enums.WebTransportCongestionControl = null,
    anticipatedConcurrentIncomingUnidirectionalStreams: ?u16 = null,
    anticipatedConcurrentIncomingBidirectionalStreams: ?u16 = null,
    protocols: ?[]const runtime.DOMString = null,
    datagramsReadableType: ?enums.ReadableStreamType = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "allowPooling", .{ .boolean = false } },
        .{ "requireUnreliable", .{ .boolean = false } },
        .{ "headers", .empty_dictionary },
        .{ "serverCertificateHashes", .empty_sequence },
        .{ "congestionControl", .{ .string = "default" } },
        .{ "anticipatedConcurrentIncomingUnidirectionalStreams", .null },
        .{ "anticipatedConcurrentIncomingBidirectionalStreams", .null },
        .{ "protocols", .empty_sequence },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "anticipatedConcurrentIncomingUnidirectionalStreams", "anticipatedConcurrentIncomingBidirectionalStreams" };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "anticipatedConcurrentIncomingUnidirectionalStreams", "anticipatedConcurrentIncomingBidirectionalStreams" };
};
