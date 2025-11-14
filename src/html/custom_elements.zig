//! HTML Custom Elements - Minimal Stub
//!
//! TODO(HTML): This is a temporary mock to unblock DOM attribute change steps.
//! Replace with real HTML spec implementation when available.
//!
//! Spec: https://html.spec.whatwg.org/#custom-elements

const std = @import("std");

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
