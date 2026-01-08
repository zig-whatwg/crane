//! DOM Registry Cleanup
//!
//! This module provides cleanup functions for DOM-related registries.
//! During normal operation, DOM nodes are cleaned up when their parent is deinited.
//! However, if nodes are removed from the tree (via removeChild) and not explicitly
//! deinited, their internal state leaks. This module provides functions to clean
//! up ALL remaining internal states regardless of tree position.
//!
//! This is especially important for WPT tests where testharness.js often modifies
//! the DOM by removing script elements and other nodes.

// Import impl modules that have registries we need to clean up
// Note: We import directly from the same directory to avoid cross-module issues
const NodeImpl = @import("Node.zig");
const ElementImpl = @import("Element.zig");
const HTMLElementImpl = @import("HTMLElement.zig");
const HTMLScriptElementImpl = @import("HTMLScriptElement.zig");
const DocumentImpl = @import("Document.zig");
const TextImpl = @import("Text.zig");
const CommentImpl = @import("Comment.zig");
const CharacterDataImpl = @import("CharacterData.zig");
const DocumentTypeImpl = @import("DocumentType.zig");
const DocumentFragmentImpl = @import("DocumentFragment.zig");
const EventTargetImpl = @import("EventTarget.zig");

// Worklet global scope impls with registries
const PaintWorkletGlobalScopeImpl = @import("PaintWorkletGlobalScope.zig");
const AnimationWorkletGlobalScopeImpl = @import("AnimationWorkletGlobalScope.zig");
const LayoutWorkletGlobalScopeImpl = @import("LayoutWorkletGlobalScope.zig");

/// Clean up ALL remaining internal states in DOM-related registries.
/// This should be called during final context cleanup, BEFORE the ArenaAllocator
/// is deinited, to ensure all owned strings and resources are properly freed.
///
/// This handles the case where DOM nodes were removed from the tree (orphaned)
/// but never explicitly deinited. Without this cleanup, their internal state
/// (strings, attributes, etc.) would leak.
pub fn cleanupAllDomRegistries() void {
    // Clean up EventTarget first - this cleans up event listener callbacks
    // which need V8 to still be alive to dispose global handles
    EventTargetImpl.cleanupAllRemainingInternal();

    // Clean up specific element types first (most derived to least)
    HTMLScriptElementImpl.cleanupAllRemainingInternal();
    HTMLElementImpl.cleanupAllRemainingInternal();
    ElementImpl.cleanupAllRemainingInternal();

    // Clean up other node types
    TextImpl.cleanupAllRemainingInternal();
    CommentImpl.cleanupAllRemainingInternal();
    DocumentTypeImpl.cleanupAllRemainingInternal();
    DocumentFragmentImpl.cleanupAllRemainingInternal();

    // Clean up base types last
    CharacterDataImpl.cleanupAllRemainingInternal();
    NodeImpl.cleanupAllRemainingInternal();
    DocumentImpl.cleanupAllRemainingInternal();

    // Clean up worklet registries
    PaintWorkletGlobalScopeImpl.deinitRegistry();
    AnimationWorkletGlobalScopeImpl.deinitRegistry();
    LayoutWorkletGlobalScopeImpl.deinitRegistry();
}
