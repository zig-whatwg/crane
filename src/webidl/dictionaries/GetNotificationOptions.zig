//! WebIDL dictionary: GetNotificationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GetNotificationOptions = struct {
    tag: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "tag", .{ .string = "" } },
    };
};
