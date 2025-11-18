//! WebIDL dictionary: NotificationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const NotificationEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    notification: anyopaque,
    action: ?runtime.DOMString = null,
};
