//! WebIDL dictionary: PushEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PushEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    data: ?*const anyopaque = null,
    notification: ?*const anyopaque = null,
};
