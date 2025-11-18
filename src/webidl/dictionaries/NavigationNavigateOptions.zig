//! WebIDL dictionary: NavigationNavigateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const NavigationOptions = @import("NavigationOptions.zig").NavigationOptions;

pub const NavigationNavigateOptions = struct {
    // Inherited from NavigationOptions
    base: NavigationOptions,

    state: ?anyopaque = null,
    history: ?anyopaque = null,
};
