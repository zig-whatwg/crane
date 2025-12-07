//! WebIDL dictionary: NavigationNavigateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const NavigationOptions = @import("NavigationOptions.zig").NavigationOptions;

pub const NavigationNavigateOptions = struct {
    // Inherited from NavigationOptions
    base: NavigationOptions,

    state: ?v8.JSValue = null,
    history: ?enums.NavigationHistoryBehavior = null,
};
