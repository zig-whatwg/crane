//! WebIDL dictionary: ResponseInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ResponseInit = struct {
    status: ?u16 = null,
    statusText: ?runtime.ByteString = null,
    headers: ?typedefs.HeadersInit = null,

    /// WebIDL ByteString members: a code unit above 0xFF throws a TypeError
    /// when the dictionary is converted.
    pub const byte_string_members = .{"statusText"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "status", .{ .number = 200 } },
        .{ "statusText", .{ .string = "" } },
    };
};
