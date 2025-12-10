//! WebIDL dictionary: NavigationInterceptOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const enums = @import("enums");

pub const NavigationInterceptOptions = struct {
    precommitHandler: ?callbacks.NavigationPrecommitHandler = null,
    handler: ?callbacks.NavigationInterceptHandler = null,
    focusReset: ?enums.NavigationFocusReset = null,
    scroll: ?enums.NavigationScrollBehavior = null,
};
