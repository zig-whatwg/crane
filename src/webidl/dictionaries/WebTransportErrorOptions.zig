//! WebIDL dictionary: WebTransportErrorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const WebTransportErrorOptions = struct {
    source: ?enums.WebTransportErrorSource = null,
    streamErrorCode: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "source", .{ .string = "stream" } },
        .{ "streamErrorCode", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"streamErrorCode"};

    /// [Clamp] members: converted with that branch of ConvertToInt.
    pub const clamp_members = .{"streamErrorCode"};
};
