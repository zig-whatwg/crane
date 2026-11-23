//! WebIDL dictionary: PeriodicSyncEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const PeriodicSyncEventInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    tag: runtime.DOMString,
};
