//! WebIDL dictionary: ShadowRootInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ShadowRootInit = struct {
    mode: *const anyopaque,
    delegatesFocus: ?bool = null,
    slotAssignment: ?*const anyopaque = null,
    clonable: ?bool = null,
    serializable: ?bool = null,
    customElementRegistry: ?*const anyopaque = null,
};
