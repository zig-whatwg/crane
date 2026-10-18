//! WebIDL dictionary: NavigationPreloadState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const NavigationPreloadState = struct {
    enabled: ?bool = null,
    headerValue: ?runtime.ByteString = null,

    /// WebIDL ByteString members: a code unit above 0xFF throws a TypeError
    /// when the dictionary is converted.
    pub const byte_string_members = .{"headerValue"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "enabled", .{ .boolean = false } },
    };
};
