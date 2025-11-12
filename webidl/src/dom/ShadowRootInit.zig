//! ShadowRootInit dictionary per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#dictdef-shadowrootinit

const ShadowRootMode = @import("shadow_root").ShadowRootMode;
const SlotAssignmentMode = @import("shadow_root").SlotAssignmentMode;

/// DOM §4.10.2 - ShadowRootInit dictionary
///
/// Options for creating a shadow root via Element.attachShadow().
pub const ShadowRootInit = struct {
    /// Required: Mode of the shadow root ("open" or "closed")
    mode: ShadowRootMode,

    /// Whether focus is delegated to the first focusable element
    delegatesFocus: bool = false,

    /// How slottables are assigned to slots
    slotAssignment: SlotAssignmentMode = .named,

    /// Whether the shadow root can be cloned
    clonable: bool = false,

    /// Whether the shadow root can be serialized
    serializable: bool = false,

    /// Custom element registry for the shadow root
    customElementRegistry: ?*anyopaque = null,
};
