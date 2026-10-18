//! WebIDL dictionary: NavigationNavigateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const NavigationOptions = @import("NavigationOptions.zig").NavigationOptions;

pub const NavigationNavigateOptions = struct {
    // Inherited from NavigationOptions
    base: NavigationOptions,

    state: ?runtime.JSValue = null,
    history: ?enums.NavigationHistoryBehavior = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"state"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "history", .{ .string = "auto" } },
    };
};
