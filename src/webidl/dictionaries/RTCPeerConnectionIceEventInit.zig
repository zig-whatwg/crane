//! WebIDL dictionary: RTCPeerConnectionIceEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const RTCPeerConnectionIceEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    candidate: ?*runtime.Instance = null,
    url: ?runtime.USVString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "candidate", "url" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "candidate", "RTCIceCandidate" },
    };
};
