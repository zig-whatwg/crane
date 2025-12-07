//! WebIDL dictionary: NavigationInterceptOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const callbacks = @import("callbacks");

pub const NavigationInterceptOptions = struct {
    precommitHandler: ?callbacks.NavigationPrecommitHandler = null,
    handler: ?callbacks.NavigationInterceptHandler = null,
    focusReset: ?enums.NavigationFocusReset = null,
    scroll: ?enums.NavigationScrollBehavior = null,
};
