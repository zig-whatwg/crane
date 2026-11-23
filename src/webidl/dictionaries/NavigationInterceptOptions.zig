//! WebIDL dictionary: NavigationInterceptOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const callbacks = @import("callbacks");

pub const NavigationInterceptOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    precommitHandler: ?callbacks.NavigationPrecommitHandler = null,
    handler: ?callbacks.NavigationInterceptHandler = null,
    focusReset: ?enums.NavigationFocusReset = null,
    scroll: ?enums.NavigationScrollBehavior = null,
};
