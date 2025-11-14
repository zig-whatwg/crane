//! HTML Custom Elements - Minimal Stub
//!
//! TODO(HTML): This is a temporary mock to unblock DOM attribute change steps.
//! Replace with real HTML spec implementation when available.
//!
//! Spec: https://html.spec.whatwg.org/#custom-elements

const std = @import("std");
const Node = @import("../dom/node.zig").Node;

/// Enqueue a custom element callback reaction
/// Spec: https://html.spec.whatwg.org/#enqueue-a-custom-element-callback-reaction
///
/// Stub: Does nothing (no custom elements supported yet)
///
/// Arguments should be:
///   - element: The custom element
///   - callback_name: "attributeChangedCallback", "connectedCallback", etc.
///   - args: Tuple of arguments for the callback
pub fn enqueueCustomElementCallbackReaction(
    element: anytype,
    callback_name: []const u8,
    args: anytype,
) void {
    _ = element;
    _ = callback_name;
    _ = args;

    // TODO(HTML): Implement custom element reactions:
    // 1. Check if element is custom
    // 2. Get element's custom element definition
    // 3. Check if definition includes callback_name
    // 4. Enqueue reaction to element's custom element reaction queue
    // 5. Ensure custom element reactions stack is not empty
    // 6. Add element to current element queue

    // For now, this is a no-op since we don't have custom elements
}

/// Run custom element adoption steps
/// Spec: https://html.spec.whatwg.org/#concept-try-upgrade (referenced in adopt)
///
/// Stub: Does nothing (no custom elements supported yet)
///
/// Called when a node is adopted to a new document
pub fn runCustomElementAdoptionSteps(
    element: anytype,
    old_document: anytype,
    new_document: anytype,
) void {
    _ = element;
    _ = old_document;
    _ = new_document;

    // TODO(HTML): Implement adoption steps:
    // 1. Check if element is custom
    // 2. Enqueue adoptedCallback if defined

    // For now, this is a no-op
}

/// Enqueue custom element adoptedCallback
/// Spec: https://html.spec.whatwg.org/#concept-custom-element-adopted-callback
///
/// Stub: Does nothing (no custom elements supported yet)
pub fn enqueueAdoptedCallback(
    element: anytype,
    old_document: anytype,
    new_document: anytype,
) void {
    _ = element;
    _ = old_document;
    _ = new_document;

    // TODO(HTML): Implement adoptedCallback reaction:
    // 1. Check if element is custom
    // 2. Enqueue callback reaction with old and new document

    // For now, this is a no-op
}

/// Enqueue custom element connectedMoveCallback
/// Spec: https://html.spec.whatwg.org/#custom-element-reactions (connectedMoveCallback)
///
/// Stub: Does nothing (no custom elements supported yet)
///
/// Called when a custom element is moved within the tree and remains connected
/// This is distinct from disconnectedCallback + connectedCallback sequence
pub fn enqueueConnectedMoveCallback(
    element: anytype,
    old_parent: anytype,
) void {
    _ = element;
    _ = old_parent;

    // TODO(HTML): Implement connectedMoveCallback reaction:
    // 1. Check if element is custom
    // 2. Check if element's root is connected
    // 3. Enqueue connectedMoveCallback reaction with old parent

    // For now, this is a no-op
}

/// Moving steps callback for custom elements
/// This is registered with the DOM mutation system via registerMovingStepsCallback
/// Spec: https://dom.spec.whatwg.org/#concept-node-move step 24.2
fn customElementMovingSteps(node: *Node, old_parent: ?*Node) void {
    // Step 24.2: If inclusiveDescendant is custom and newParent is connected,
    // enqueue connectedMoveCallback reaction

    // Check if node has a parent (newParent in spec terminology)
    const new_parent = node.parent_node orelse return;

    // Check if new parent's root is connected
    // TODO(HTML): Implement proper is_connected check
    // For now, we can't determine if connected without full DOM implementation
    _ = new_parent;

    // TODO(HTML): Check if node is a custom element
    // For now, this is a no-op since custom elements aren't implemented
    _ = old_parent;

    // When custom elements are implemented:
    // if (node.is_custom_element()) {
    //     const root = tree_helpers.root(new_parent);
    //     if (root.is_connected()) {
    //         enqueueConnectedMoveCallback(node, old_parent);
    //     }
    // }
}

/// Initialize custom element moving steps
/// Call this during DOM initialization to register the moving steps callback
pub fn initializeCustomElementMovingSteps() !void {
    const mutation = @import("../dom/mutation.zig");
    try mutation.registerMovingStepsCallback(customElementMovingSteps);
}
