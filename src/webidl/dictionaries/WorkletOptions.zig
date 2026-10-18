//! WebIDL dictionary: WorkletOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const WorkletOptions = struct {
    credentials: ?enums.RequestCredentials = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "credentials", .{ .string = "same-origin" } },
    };
};
