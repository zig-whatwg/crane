//! WebIDL dictionary: RTCLocalIceCandidateInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const RTCIceCandidateInit = @import("RTCIceCandidateInit.zig").RTCIceCandidateInit;

pub const RTCLocalIceCandidateInit = struct {
    // Inherited from RTCIceCandidateInit
    base: RTCIceCandidateInit,

    relayProtocol: ?enums.RTCIceServerTransportProtocol = null,
    url: ?runtime.USVString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "relayProtocol", .null },
        .{ "url", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "relayProtocol", "url" };
};
