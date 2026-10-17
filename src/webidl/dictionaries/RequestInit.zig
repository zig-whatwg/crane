//! WebIDL dictionary: RequestInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const PrivateToken = @import("PrivateToken.zig").PrivateToken;

pub const RequestInit = struct {
    method: ?runtime.ByteString = null,
    headers: ?typedefs.HeadersInit = null,
    body: ?typedefs.BodyInit = null,
    referrer: ?runtime.USVString = null,
    referrerPolicy: ?enums.ReferrerPolicy = null,
    mode: ?enums.RequestMode = null,
    credentials: ?enums.RequestCredentials = null,
    cache: ?enums.RequestCache = null,
    redirect: ?enums.RequestRedirect = null,
    integrity: ?runtime.DOMString = null,
    keepalive: ?bool = null,
    signal: ?*runtime.Instance = null,
    duplex: ?enums.RequestDuplex = null,
    priority: ?enums.RequestPriority = null,
    window: ?runtime.JSValue = null,
    targetAddressSpace: ?enums.IPAddressSpace = null,
    privateToken: ?PrivateToken = null,

    /// WebIDL ByteString members: a code unit above 0xFF throws a TypeError
    /// when the dictionary is converted.
    pub const byte_string_members = .{"method"};

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"window"};

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "body", "signal" };
};
