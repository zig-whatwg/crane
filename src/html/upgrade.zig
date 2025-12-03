//! Custom Element Upgrade Algorithm
//!
//! Implements the custom element upgrade algorithm per HTML Standard §4.13.6
//! Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#concept-upgrade-an-element
//!
//! ## Overview
//!
//! When a custom element is defined after elements with that name already exist in the DOM,
//! those elements need to be "upgraded" to use the custom element's constructor and
//! gain access to its lifecycle callbacks.
//!
//! ## Algorithm Steps (per spec)
//!
//! 1. Set element's custom element state to "failed" (in case of exception)
//! 2. Push a new entry to construction stack
//! 3. Let constructResult be Construct(C) (call the constructor)
//! 4. If constructResult is element:
//!    - If element has connected, enqueue connectedCallback
//!    - Set custom element state to "custom"
//! 5. Pop construction stack
//!
//! ## Related Functions
//!
//! - tryToUpgrade(): Looks up definition and enqueues upgrade reaction
//! - upgradeElement(): Performs the actual upgrade (this module)
//! - upgradeSubtree(): Upgrades all matching elements in a subtree

const std = @import("std");
const Allocator = std.mem.Allocator;
const custom_elements = @import("custom_elements.zig");
const CustomElementDefinition = custom_elements.CustomElementDefinition;

// Import WebIDL types for custom element registry
const webidl_impls = @import("webidl").impls;
const CustomElementRegistryImpl = webidl_impls.CustomElementRegistry;

/// Custom element state enumeration
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element-state
pub const CustomElementState = enum {
    /// Element is not a custom element
    undefined,
    /// Element upgrade failed with an exception
    failed,
    /// Element is a customized built-in that hasn't been upgraded
    uncustomized,
    /// Element upgrade is in progress
    precustomized,
    /// Element is a fully upgraded custom element
    custom,
};

/// Element upgrade context
/// Tracks state during the upgrade process
pub const UpgradeContext = struct {
    element: *anyopaque,
    definition: *CustomElementDefinition,
    allocator: Allocator,
    state: CustomElementState = .undefined,

    /// Whether the element is connected to a document
    is_connected: bool = false,
};

/// Try to upgrade an element
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#concept-try-upgrade
///
/// This is called when:
/// - An element is created and a definition already exists
/// - An element is inserted into a document
/// - An element's is attribute changes
pub fn tryToUpgrade(
    allocator: Allocator,
    element: *anyopaque,
    local_name: []const u8,
    namespace: ?[]const u8,
    is_value: ?[]const u8,
    registry: ?*anyopaque, // CustomElementRegistry instance
) !void {
    // Step 1: Look up a custom element definition
    const definition = CustomElementRegistryImpl.lookUpCustomElementDefinition(
        @ptrCast(registry),
        namespace,
        local_name,
        is_value,
    );

    // Step 2: If definition is null, return
    if (definition == null) return;

    // Step 3: Enqueue a custom element upgrade reaction
    try custom_elements.enqueueCustomElementUpgradeReaction(allocator, element, definition.?);
}

/// Upgrade an element to its custom element definition
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#concept-upgrade-an-element
///
/// This is called when processing an upgrade reaction from the reaction queue.
pub fn upgradeElement(
    allocator: Allocator,
    element: *anyopaque,
    definition: *CustomElementDefinition,
    is_connected: bool,
) UpgradeError!void {
    // Create upgrade context
    var ctx = UpgradeContext{
        .element = element,
        .definition = definition,
        .allocator = allocator,
        .is_connected = is_connected,
    };

    // Step 1: If element's custom element state is not "undefined" or "uncustomized", return
    // Note: In a real implementation, we'd check the element's actual state
    // For now, we assume the element is upgradeable

    // Step 2: Set element's custom element definition to definition
    // Note: This requires storing a pointer in the element - needs DOM integration

    // Step 3: Set element's custom element state to "failed"
    // (This is for exception safety - we set it to "custom" if successful)
    ctx.state = .failed;

    // Step 4: For each observed attribute, enqueue attributeChangedCallback
    // Note: This requires reading the element's current attributes - needs DOM integration
    // For now, this is a TODO

    // Step 5: If element is currently connected, enqueue connectedCallback
    // Note: After the constructor runs
    // We track this for later

    // Step 6: Add element to construction stack
    try definition.construction_stack.append(definition.allocator, .{ .element = @ptrCast(element) });
    errdefer {
        _ = definition.construction_stack.pop();
    }

    // Step 7-8: Run the constructor
    // Note: This requires V8 integration to actually call the constructor
    // For now, we just validate the constructor exists
    _ = definition.constructor; // The constructor function pointer

    // In a real implementation:
    // const construct_result = try v8.construct(definition.constructor);
    // if (construct_result != element) {
    //     return error.InvalidConstructorResult;
    // }

    // Step 9: Pop from construction stack
    _ = definition.construction_stack.pop();

    // Step 10: Set custom element state to "custom"
    ctx.state = .custom;

    // Step 11: If connected, enqueue connectedCallback
    if (ctx.is_connected) {
        try custom_elements.enqueueConnectedCallback(allocator, element, definition);
    }
}

/// Errors that can occur during element upgrade
pub const UpgradeError = error{
    /// Constructor returned a different element
    InvalidConstructorResult,
    /// Constructor threw an exception
    ConstructorException,
    /// Element is not upgradeable (already upgraded or failed)
    NotUpgradeable,
    /// Memory allocation failed
    OutOfMemory,
};

/// Upgrade all matching elements in a subtree
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-upgrade
///
/// Called by customElements.upgrade(root)
pub fn upgradeSubtree(
    allocator: Allocator,
    root: *anyopaque,
    registry: *anyopaque,
) !void {
    _ = allocator;
    _ = root;
    _ = registry;

    // TODO: Implement subtree upgrade:
    // 1. Let candidates be root's shadow-including inclusive descendant elements
    // 2. For each candidate in candidates (in shadow-including tree order):
    //    a. Try to upgrade candidate

    // This requires DOM tree traversal which needs deeper integration
}

/// Check if an element should be created as a custom element
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#concept-create-element
///
/// Called during element creation to determine if the element should be
/// created synchronously as a custom element.
pub fn shouldCreateAsCustomElement(
    local_name: []const u8,
    namespace: ?[]const u8,
    is_value: ?[]const u8,
    registry: ?*anyopaque,
) bool {
    // Look up definition
    const definition = CustomElementRegistryImpl.lookUpCustomElementDefinition(
        @ptrCast(registry),
        namespace,
        local_name,
        is_value,
    );

    return definition != null;
}

// ============================================================================
// Tests
// ============================================================================

test "CustomElementState enum" {
    const state = CustomElementState.custom;
    try std.testing.expect(state == .custom);

    const failed = CustomElementState.failed;
    try std.testing.expect(failed == .failed);
}

test "UpgradeContext initialization" {
    const allocator = std.testing.allocator;

    // Mock element and definition
    var mock_element: u8 = 0;

    // Create a mock definition (would normally come from CustomElementRegistry)
    // For testing, we just verify the context struct works
    const ctx = UpgradeContext{
        .element = &mock_element,
        .definition = undefined, // Would be a real definition
        .allocator = allocator,
        .is_connected = true,
    };

    try std.testing.expect(ctx.is_connected == true);
    try std.testing.expect(ctx.state == .undefined);
}

test "shouldCreateAsCustomElement with no registry" {
    // No registry means no custom element definition
    const result = shouldCreateAsCustomElement("my-element", "http://www.w3.org/1999/xhtml", null, null);
    try std.testing.expect(result == false);
}
