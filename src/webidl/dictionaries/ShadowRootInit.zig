//! WebIDL dictionary: ShadowRootInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ShadowRootInit = struct {
    mode: enums.ShadowRootMode,
    delegatesFocus: ?bool = null,
    slotAssignment: ?enums.SlotAssignmentMode = null,
    clonable: ?bool = null,
    serializable: ?bool = null,
    customElementRegistry: ?*runtime.Instance = null,
};
