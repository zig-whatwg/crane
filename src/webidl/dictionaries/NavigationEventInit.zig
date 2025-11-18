//! WebIDL dictionary: NavigationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const UIEventInit = @import("UIEventInit.zig").UIEventInit;

pub const NavigationEventInit = struct {
    // Inherited from UIEventInit
    base: UIEventInit,

    dir: ?anyopaque = null,
    relatedTarget: ?anyopaque = null,
};
