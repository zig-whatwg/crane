//! WebIDL dictionary: SyncEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const SyncEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    tag: runtime.DOMString,
    lastChance: ?bool = null,
};
