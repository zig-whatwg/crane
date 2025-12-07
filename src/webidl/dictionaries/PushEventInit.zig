//! WebIDL dictionary: PushEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PushEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    data: ?typedefs.PushMessageDataInit = null,
    notification: ?*runtime.Instance = null,
};
