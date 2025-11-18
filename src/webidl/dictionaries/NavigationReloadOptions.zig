//! WebIDL dictionary: NavigationReloadOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const NavigationOptions = @import("NavigationOptions.zig").NavigationOptions;

pub const NavigationReloadOptions = struct {
    // Inherited from NavigationOptions
    base: NavigationOptions,

    state: ?anyopaque = null,
};
