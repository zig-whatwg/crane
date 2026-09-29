//! WebIDL dictionary: NavigationReloadOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const NavigationOptions = @import("NavigationOptions.zig").NavigationOptions;

pub const NavigationReloadOptions = struct {
    // Inherited from NavigationOptions
    base: NavigationOptions,

    state: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"state"};
};
