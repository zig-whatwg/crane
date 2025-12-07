//! WebIDL dictionary: NotificationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const NotificationEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    notification: *runtime.Instance,
    action: ?runtime.DOMString = null,
};
