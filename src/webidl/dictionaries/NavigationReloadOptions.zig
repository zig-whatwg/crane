//! WebIDL dictionary: NavigationReloadOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const NavigationOptions = @import("NavigationOptions.zig").NavigationOptions;

pub const NavigationReloadOptions = struct {
    // Inherited from NavigationOptions
    base: NavigationOptions,

    state: ?v8.JSValue = null,
};
