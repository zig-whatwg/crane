//! DocumentOrShadowRoot mixin per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#documentorshadowroot

const std = @import("std");
const webidl = @import("webidl");

/// DOM §4.4 - DocumentOrShadowRoot mixin
///
/// This mixin defines APIs shared between Document and ShadowRoot.
/// It's expected to be used by other standards as well.
pub const DocumentOrShadowRoot = webidl.mixin(struct {
    /// Custom element registry for this document or shadow root
    custom_element_registry: ?*anyopaque = null,

    // ========================================================================
    // Attributes
    // ========================================================================

    /// DOM §4.4 - DocumentOrShadowRoot.customElementRegistry
    ///
    /// Returns this's CustomElementRegistry object, if any; otherwise null.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-documentorshadowroot-customelementregistry
    pub fn get_customElementRegistry(self: *const @This()) ?*anyopaque {
        // Step 1: If this is a document, then return this's custom element registry
        // Step 2: Assert: this is a ShadowRoot node
        // Step 3: Return this's custom element registry

        // Both cases just return the custom_element_registry field
        return self.custom_element_registry;
    }

    // ========================================================================
    // Internal Methods
    // ========================================================================

    /// Get the custom element registry
    pub fn getCustomElementRegistry(self: *const @This()) ?*anyopaque {
        return self.custom_element_registry;
    }

    /// Set the custom element registry
    pub fn setCustomElementRegistry(self: *@This(), registry: ?*anyopaque) void {
        self.custom_element_registry = registry;
    }
});

// Tests


