//! DocumentOrShadowRoot's fullscreenElement, pointerLockElement and
//! pictureInPictureElement: each reads its node document's ONE element of that
//! kind - kept in the document's rare data (dom.document_rare_data) - retargeted
//! against `this`, the document or a shadow root. A shadow root keeps none of
//! its own.
//!
//! - Fullscreen, "The fullscreenElement getter steps":
//!   1. If this is a shadow root and its host is not connected, then return null.
//!   2. Let candidate be the result of retargeting fullscreen element against this.
//!   3. If candidate and this are in the same tree, then return candidate.
//!   4. Return null.
//! - Picture-in-Picture 4.3, pictureInPictureElement: the same four steps over
//!   the Picture-in-Picture element.
//! - Pointer Lock 2.0, pointerLockElement: "the result of retargeting the
//!   element, which is the target for mouse events, against this element if the
//!   result and this element are in the same tree, otherwise returns null" -
//!   no step 1.
//!
//! Blink keeps each element once per document (its Fullscreen,
//! PointerLockController and PictureInPictureController supplements) and
//! adjusts it to the asking tree scope (Fullscreen::FullscreenElementForBindingFrom
//! -> TreeScope::AdjustedElement); WebKit's TreeScope does the same
//! (ancestorElementInThisScope). Crane's three elements are never set yet: no
//! fullscreen, pointer lock or Picture-in-Picture request runs.

const runtime = @import("runtime");
const NodeBase = @import("node_base.zig").NodeBase;
const retarget = @import("retarget.zig");
const document_internals = @import("document_internals.zig");

pub const Kind = enum { fullscreen, pointer_lock, picture_in_picture };

/// `kind`'s element for `this` (a Document or a ShadowRoot), retargeted
/// against it; null when there is none, or it is in another tree.
pub fn of(this: *runtime.Instance, kind: Kind) ?*runtime.Instance {
    const this_node = retarget.nodeOf(this) orelse return null;
    // Fullscreen and Picture-in-Picture step 1.
    if (kind != .pointer_lock and retarget.isShadowRoot(this_node)) {
        const host = retarget.hostOf(this_node) orelse return null;
        if (!host.is_connected) return null;
    }
    const element = designated(this_node, kind) orelse return null;
    // Step 2: "Let candidate be the result of retargeting [the element]
    // against this."
    const candidate = retarget.retarget(element, this) catch return null;
    // Step 3: "If candidate and this are in the same tree, then return
    // candidate."
    const candidate_node = retarget.nodeOf(candidate) orelse return null;
    if (retarget.rootOf(candidate_node) == retarget.rootOf(this_node)) return candidate;
    // Step 4.
    return null;
}

/// The node document's `kind` element, as its document keeps it.
fn designated(this_node: *NodeBase, kind: Kind) ?*runtime.Instance {
    const document_node: *NodeBase = if (this_node.node_type == NodeBase.DOCUMENT_NODE)
        this_node
    else
        this_node.documentBase() orelse return null;
    const document = retarget.instanceOf(document_node) orelse return null;
    const internal = document_internals.getInternal(document) orelse return null;
    const rare = internal.rareData() orelse return null;
    return switch (kind) {
        .fullscreen => rare.fullscreen_element,
        .pointer_lock => rare.pointer_lock_element,
        .picture_in_picture => rare.picture_in_picture_element,
    };
}
