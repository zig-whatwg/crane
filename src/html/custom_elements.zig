//! HTML Custom Elements
//!
//! Implements custom element reactions and lifecycle callbacks per HTML Standard §4.13.5
//! Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element-reactions
//!
//! ## Overview
//!
//! Custom elements allow authors to build their own DOM elements. This module implements:
//! - Custom element reaction queue management
//! - Lifecycle callback invocation (connectedCallback, disconnectedCallback, etc.)
//! - Element upgrade algorithm integration
//!
//! ## Architecture
//!
//! This module provides the reaction queue infrastructure that works with:
//! - CustomElementRegistry (defines custom elements)
//! - CustomElementDefinition (stores element definition data)
//! - DOM mutation operations (triggers reactions)
//!
//! ## Reaction Types
//!
//! - **Upgrade reaction**: Upgrades an element to its custom definition
//! - **Callback reaction**: Invokes a lifecycle callback with arguments

const std = @import("std");
const Allocator = std.mem.Allocator;
const dom = @import("dom");
const Node = dom.node.Node;

// Import WebIDL types for custom element registry
// This module is only available from the full html module (full.zig), NOT from html_core.
// This is because it requires access to CustomElementDefinition fields.
const impls = @import("impls");
const CustomElementRegistryImpl = impls.CustomElementRegistry;
pub const CustomElementDefinition = CustomElementRegistryImpl.CustomElementDefinition;

/// Reaction type enumeration
pub const ReactionType = enum {
    upgrade,
    callback,
};

/// Callback reaction types
pub const CallbackType = enum {
    connected,
    disconnected,
    adopted,
    connected_move,
    attribute_changed,
    form_associated,
    form_reset,
    form_disabled,
    form_state_restore,
};

/// A custom element reaction
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element-reaction-queue
pub const Reaction = struct {
    reaction_type: ReactionType,

    /// For upgrade reactions
    definition: ?*CustomElementDefinition = null,

    /// For callback reactions
    callback_type: ?CallbackType = null,
    callback_args: ?CallbackArgs = null,

    pub const CallbackArgs = union(enum) {
        none: void,
        attribute_changed: AttributeChangedArgs,
        adopted: AdoptedArgs,
    };

    pub const AttributeChangedArgs = struct {
        local_name: []const u8,
        old_value: ?[]const u8,
        new_value: ?[]const u8,
        namespace: ?[]const u8,
    };

    pub const AdoptedArgs = struct {
        old_document: *anyopaque,
        new_document: *anyopaque,
    };
};

/// Element reaction queue
/// Each custom element has its own queue of pending reactions
pub const ReactionQueue = struct {
    reactions: std.ArrayListUnmanaged(Reaction),
    allocator: Allocator,

    pub fn init(allocator: Allocator) ReactionQueue {
        return .{
            .reactions = std.ArrayListUnmanaged(Reaction){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ReactionQueue) void {
        self.reactions.deinit(self.allocator);
    }

    pub fn enqueue(self: *ReactionQueue, reaction: Reaction) !void {
        try self.reactions.append(self.allocator, reaction);
    }

    pub fn dequeue(self: *ReactionQueue) ?Reaction {
        if (self.reactions.items.len == 0) return null;
        const item = self.reactions.orderedRemove(0);
        return item;
    }

    pub fn isEmpty(self: *const ReactionQueue) bool {
        return self.reactions.items.len == 0;
    }

    pub fn clear(self: *ReactionQueue) void {
        self.reactions.clearRetainingCapacity();
    }
};

/// Element queue for the custom element reactions stack
/// Uses ArrayListUnmanaged since these queues are stored inside another collection
pub const ElementQueue = std.ArrayListUnmanaged(*anyopaque); // *Element opaque pointers

/// Stack of element queues - also uses ArrayListUnmanaged
pub const ElementQueueStack = std.ArrayListUnmanaged(ElementQueue);

/// Custom element reactions stack
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element-reactions-stack
pub const ReactionsStack = struct {
    stack: ElementQueueStack,
    backup_queue: ElementQueue,
    processing_backup: bool = false,
    allocator: Allocator,

    pub fn init(allocator: Allocator) ReactionsStack {
        return .{
            .stack = ElementQueueStack{},
            .backup_queue = ElementQueue{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ReactionsStack) void {
        for (self.stack.items) |*queue| {
            queue.deinit(self.allocator);
        }
        self.stack.deinit(self.allocator);
        self.backup_queue.deinit(self.allocator);
    }

    pub fn push(self: *ReactionsStack) !void {
        const queue = ElementQueue{};
        try self.stack.append(self.allocator, queue);
    }

    pub fn pop(self: *ReactionsStack) ?ElementQueue {
        return self.stack.pop();
    }

    pub fn currentElementQueue(self: *ReactionsStack) ?*ElementQueue {
        if (self.stack.items.len == 0) return null;
        return &self.stack.items[self.stack.items.len - 1];
    }

    pub fn isEmpty(self: *const ReactionsStack) bool {
        return self.stack.items.len == 0;
    }
};

// Thread-local reactions stack
// In a real implementation, this would be per-agent (similar-origin window agent)
threadlocal var reactions_stack: ?ReactionsStack = null;

// Thread-local element reaction queues
// Maps element pointers to their reaction queues
threadlocal var element_reaction_queues: ?std.AutoHashMap(*anyopaque, ReactionQueue) = null;

/// Get or initialize the reactions stack for the current agent
pub fn getReactionsStack(allocator: Allocator) *ReactionsStack {
    if (reactions_stack == null) {
        reactions_stack = ReactionsStack.init(allocator);
    }
    return &reactions_stack.?;
}

/// Get or initialize the element reaction queues map
fn getElementReactionQueues(allocator: Allocator) *std.AutoHashMap(*anyopaque, ReactionQueue) {
    if (element_reaction_queues == null) {
        element_reaction_queues = std.AutoHashMap(*anyopaque, ReactionQueue).init(allocator);
    }
    return &element_reaction_queues.?;
}

/// Get or create reaction queue for an element
/// Spec: custom element reaction queue per element
pub fn getOrCreateReactionQueue(allocator: Allocator, element: *anyopaque) !*ReactionQueue {
    const queues = getElementReactionQueues(allocator);
    const result = try queues.getOrPut(element);
    if (!result.found_existing) {
        result.value_ptr.* = ReactionQueue.init(allocator);
    }
    return result.value_ptr;
}

/// Clean up reaction queue for an element (call when element is destroyed)
pub fn removeReactionQueue(allocator: Allocator, element: *anyopaque) void {
    const queues = getElementReactionQueues(allocator);
    if (queues.fetchRemove(element)) |kv| {
        var queue = kv.value;
        queue.deinit();
    }
}

/// Clean up all thread-local custom element state
/// This is primarily for testing - in production the thread-local state
/// lives for the duration of the agent.
pub fn deinitThreadLocalState() void {
    // Clean up element reaction queues
    if (element_reaction_queues) |*queues| {
        var iter = queues.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        queues.deinit();
        element_reaction_queues = null;
    }

    // Clean up reactions stack
    if (reactions_stack) |*stack| {
        stack.deinit();
        reactions_stack = null;
    }
}

/// Enqueue an element on the appropriate element queue
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-an-element-on-the-appropriate-element-queue
pub fn enqueueElementOnAppropriateQueue(allocator: Allocator, element: *anyopaque) !void {
    const stack = getReactionsStack(allocator);

    // Step 2: If stack is empty, use backup queue
    if (stack.isEmpty()) {
        try stack.backup_queue.append(allocator, element);

        // Step 2.2: If already processing backup, return
        if (stack.processing_backup) return;

        // Step 2.3: Set processing flag
        stack.processing_backup = true;

        // Step 2.4: Queue a microtask to process backup queue
        // TODO: Integrate with event loop microtask queue
        // For now, process immediately (synchronous fallback)
        invokeCustomElementReactions(allocator, &stack.backup_queue);
        stack.processing_backup = false;
    } else {
        // Step 3: Add to current element queue
        if (stack.currentElementQueue()) |queue| {
            try queue.append(allocator, element);
        }
    }
}

/// Enqueue a custom element callback reaction
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-a-custom-element-callback-reaction
pub fn enqueueCustomElementCallbackReaction(
    allocator: Allocator,
    element: *anyopaque,
    definition: *CustomElementDefinition,
    callback_type: CallbackType,
    args: ?Reaction.CallbackArgs,
) !void {
    // Step 1: Get the callback from definition's lifecycle callbacks
    const callback = switch (callback_type) {
        .connected => definition.lifecycle_callbacks.connectedCallback,
        .disconnected => definition.lifecycle_callbacks.disconnectedCallback,
        .adopted => definition.lifecycle_callbacks.adoptedCallback,
        .connected_move => definition.lifecycle_callbacks.connectedMoveCallback orelse
            // Fall back to connectedCallback if connectedMoveCallback not defined
            definition.lifecycle_callbacks.connectedCallback,
        .attribute_changed => definition.lifecycle_callbacks.attributeChangedCallback,
        .form_associated => definition.lifecycle_callbacks.formAssociatedCallback,
        .form_reset => definition.lifecycle_callbacks.formResetCallback,
        .form_disabled => definition.lifecycle_callbacks.formDisabledCallback,
        .form_state_restore => definition.lifecycle_callbacks.formStateRestoreCallback,
    };

    // Step 2: If callback is null, return (nothing to invoke)
    if (callback == null) return;

    // Step 3: For attributeChangedCallback, check observedAttributes
    if (callback_type == .attribute_changed) {
        if (args) |callback_args| {
            if (callback_args == .attribute_changed) {
                const attr_args = callback_args.attribute_changed;
                // Check if attribute is in observedAttributes list
                var found = false;
                for (definition.observed_attributes) |observed| {
                    if (std.mem.eql(u8, observed, attr_args.local_name)) {
                        found = true;
                        break;
                    }
                }
                if (!found) return; // Attribute not observed, skip
            }
        }
    }

    // Step 4: Add callback reaction to element's reaction queue
    const queue = try getOrCreateReactionQueue(allocator, element);
    try queue.enqueue(.{
        .reaction_type = .callback,
        .definition = definition,
        .callback_type = callback_type,
        .callback_args = args,
    });

    // Step 5: Enqueue element on appropriate queue
    try enqueueElementOnAppropriateQueue(allocator, element);
}

/// Enqueue a custom element upgrade reaction
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-a-custom-element-upgrade-reaction
pub fn enqueueCustomElementUpgradeReaction(allocator: Allocator, element: *anyopaque, definition: *CustomElementDefinition) !void {
    // Step 1: Add upgrade reaction to element's reaction queue
    const queue = try getOrCreateReactionQueue(allocator, element);
    try queue.enqueue(.{
        .reaction_type = .upgrade,
        .definition = definition,
    });

    // Step 2: Enqueue element on appropriate queue
    try enqueueElementOnAppropriateQueue(allocator, element);
}

/// Invoke custom element reactions in an element queue
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#invoke-custom-element-reactions
pub fn invokeCustomElementReactions(allocator: Allocator, queue: *ElementQueue) void {
    // Step 1: While queue is not empty
    while (queue.items.len > 0) {
        // Step 1.1: Let element be first element in queue
        const element = queue.orderedRemove(0);

        // Step 1.2: Get element's reaction queue
        const queues = getElementReactionQueues(allocator);
        const reaction_queue = queues.getPtr(element) orelse continue;

        // Step 1.3: Process each reaction in the element's queue
        while (reaction_queue.dequeue()) |reaction| {
            switch (reaction.reaction_type) {
                .upgrade => {
                    // Step 1.3.1: If upgrade reaction, run upgrade algorithm
                    if (reaction.definition) |definition| {
                        upgradeElement(allocator, element, definition);
                    }
                },
                .callback => {
                    // Step 1.3.2: If callback reaction, invoke callback
                    if (reaction.definition) |definition| {
                        invokeCallback(element, definition, reaction.callback_type, reaction.callback_args);
                    }
                },
            }
        }
    }
}

/// Upgrade an element to its custom element definition
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#concept-upgrade-an-element
fn upgradeElement(allocator: Allocator, element: *anyopaque, definition: *CustomElementDefinition) void {
    _ = allocator;
    _ = element;
    _ = definition;

    // TODO: Full upgrade algorithm:
    // 1. Set element's custom element state to "failed" (in case of exception)
    // 2. Push definition's construction stack entry
    // 3. Create new instance with definition's constructor
    // 4. Run connectedCallback if connected
    // 5. Set element's custom element state to "custom"

    // For now, this is a placeholder - full implementation in upgrade.zig
}

/// Invoke a lifecycle callback on an element
fn invokeCallback(
    element: *anyopaque,
    definition: *CustomElementDefinition,
    callback_type: ?CallbackType,
    args: ?Reaction.CallbackArgs,
) void {
    _ = element;

    const cb_type = callback_type orelse return;

    // Get the callback function pointer from definition
    const callback: ?*anyopaque = switch (cb_type) {
        .connected => definition.lifecycle_callbacks.connectedCallback,
        .disconnected => definition.lifecycle_callbacks.disconnectedCallback,
        .adopted => definition.lifecycle_callbacks.adoptedCallback,
        .connected_move => definition.lifecycle_callbacks.connectedMoveCallback,
        .attribute_changed => definition.lifecycle_callbacks.attributeChangedCallback,
        .form_associated => definition.lifecycle_callbacks.formAssociatedCallback,
        .form_reset => definition.lifecycle_callbacks.formResetCallback,
        .form_disabled => definition.lifecycle_callbacks.formDisabledCallback,
        .form_state_restore => definition.lifecycle_callbacks.formStateRestoreCallback,
    };

    if (callback == null) return;

    // TODO: Actually invoke the callback with V8
    // This requires integration with the JS runtime to:
    // 1. Get the callback function as a V8 Function
    // 2. Call it with element as 'this'
    // 3. Pass appropriate arguments based on callback type:
    //    - connectedCallback: no args
    //    - disconnectedCallback: no args
    //    - adoptedCallback: (oldDocument, newDocument)
    //    - attributeChangedCallback: (localName, oldValue, newValue, namespace)
    //    - formAssociatedCallback: (form)
    //    - formResetCallback: no args
    //    - formDisabledCallback: (disabled)
    //    - formStateRestoreCallback: (state, mode)

    // For now, log that we would invoke the callback
    _ = args;

    // Placeholder: In real implementation, this would call into V8
    // v8.callFunction(callback, element, args);
}

/// Run custom element adoption steps
/// Spec: https://html.spec.whatwg.org/#concept-try-upgrade (referenced in adopt)
///
/// Called when a node is adopted to a new document
pub fn runCustomElementAdoptionSteps(
    allocator: Allocator,
    element: *anyopaque,
    old_document: *anyopaque,
    new_document: *anyopaque,
    definition: ?*CustomElementDefinition,
) !void {
    // Step 1: If element has a custom element state of "custom", enqueue adoptedCallback
    // Note: Custom element state checking requires DOM integration
    // For now, we check if definition is provided (meaning element is custom)
    if (definition) |def| {
        try enqueueAdoptedCallback(allocator, element, def, old_document, new_document);
    }
}

/// Enqueue custom element adoptedCallback
/// Spec: https://html.spec.whatwg.org/#concept-custom-element-adopted-callback
pub fn enqueueAdoptedCallback(
    allocator: Allocator,
    element: *anyopaque,
    definition: *CustomElementDefinition,
    old_document: *anyopaque,
    new_document: *anyopaque,
) !void {
    try enqueueCustomElementCallbackReaction(
        allocator,
        element,
        definition,
        .adopted,
        .{ .adopted = .{
            .old_document = old_document,
            .new_document = new_document,
        } },
    );
}

/// Enqueue custom element connectedCallback
/// Spec: https://html.spec.whatwg.org/#concept-custom-element-connected-callback
///
/// Called when a custom element is inserted into a connected document
pub fn enqueueConnectedCallback(
    allocator: Allocator,
    element: *anyopaque,
    definition: *CustomElementDefinition,
) !void {
    try enqueueCustomElementCallbackReaction(
        allocator,
        element,
        definition,
        .connected,
        .{ .none = {} },
    );
}

/// Enqueue custom element disconnectedCallback
/// Spec: https://html.spec.whatwg.org/#concept-custom-element-disconnected-callback
///
/// Called when a custom element is removed from a connected document
pub fn enqueueDisconnectedCallback(
    allocator: Allocator,
    element: *anyopaque,
    definition: *CustomElementDefinition,
) !void {
    try enqueueCustomElementCallbackReaction(
        allocator,
        element,
        definition,
        .disconnected,
        .{ .none = {} },
    );
}

/// Enqueue custom element connectedMoveCallback
/// Spec: https://html.spec.whatwg.org/#custom-element-reactions (connectedMoveCallback)
///
/// Called when a custom element is moved within the tree and remains connected
pub fn enqueueConnectedMoveCallback(
    allocator: Allocator,
    element: *anyopaque,
    definition: *CustomElementDefinition,
) !void {
    try enqueueCustomElementCallbackReaction(
        allocator,
        element,
        definition,
        .connected_move,
        .{ .none = {} },
    );
}

/// Enqueue custom element attributeChangedCallback
/// Spec: https://html.spec.whatwg.org/#concept-custom-element-attribute-changed-callback
///
/// Called when an observed attribute is added, changed, or removed
pub fn enqueueAttributeChangedCallback(
    allocator: Allocator,
    element: *anyopaque,
    definition: *CustomElementDefinition,
    local_name: []const u8,
    old_value: ?[]const u8,
    new_value: ?[]const u8,
    namespace: ?[]const u8,
) !void {
    try enqueueCustomElementCallbackReaction(
        allocator,
        element,
        definition,
        .attribute_changed,
        .{ .attribute_changed = .{
            .local_name = local_name,
            .old_value = old_value,
            .new_value = new_value,
            .namespace = namespace,
        } },
    );
}

/// Moving steps callback for custom elements
/// This is registered with the DOM mutation system via registerMovingStepsCallback
/// Spec: https://dom.spec.whatwg.org/#concept-node-move step 24.2
fn customElementMovingSteps(node: *Node, old_parent: ?*Node) void {
    _ = old_parent;

    // Get the node's parent to check connectivity
    const new_parent = node.parent_node orelse return;
    _ = new_parent;

    // TODO: Implement when custom elements are fully integrated
    // Need to:
    // 1. Check if node is a custom element (has custom element state "custom")
    // 2. Get the element's custom element definition
    // 3. Check if element is now connected (root is a Document)
    // 4. Enqueue connectedMoveCallback

    // if (node.is_custom_element()) {
    //     const root = tree_helpers.root(new_parent);
    //     if (root.is_connected()) {
    //         const def = getCustomElementDefinition(node);
    //         if (def) |definition| {
    //             enqueueConnectedMoveCallback(allocator, @ptrCast(node), definition) catch {};
    //         }
    //     }
    // }
}

/// Initialize custom element moving steps
/// Call this during DOM initialization to register the moving steps callback
pub fn initializeCustomElementMovingSteps() !void {
    const dom_mod = @import("dom");
    try dom_mod.mutation.registerMovingStepsCallback(customElementMovingSteps);
}

// ============================================================================
// Tests
// ============================================================================

test "ReactionQueue basic operations" {
    const allocator = std.testing.allocator;
    var queue = ReactionQueue.init(allocator);
    defer queue.deinit();

    try std.testing.expect(queue.isEmpty());

    try queue.enqueue(.{ .reaction_type = .upgrade });
    try std.testing.expect(!queue.isEmpty());

    const reaction = queue.dequeue();
    try std.testing.expect(reaction != null);
    try std.testing.expect(reaction.?.reaction_type == .upgrade);
    try std.testing.expect(queue.isEmpty());
}

test "ReactionsStack basic operations" {
    const allocator = std.testing.allocator;
    var stack = ReactionsStack.init(allocator);
    defer stack.deinit();

    try std.testing.expect(stack.isEmpty());

    try stack.push();
    try std.testing.expect(!stack.isEmpty());

    _ = stack.pop();
    try std.testing.expect(stack.isEmpty());
}

test "element reaction queue management" {
    const allocator = std.testing.allocator;
    defer deinitThreadLocalState(); // Clean up thread-local state

    // Create a mock element pointer
    var mock_element: u8 = 0;
    const element_ptr: *anyopaque = &mock_element;

    // Get or create queue for element
    const queue = try getOrCreateReactionQueue(allocator, element_ptr);
    try std.testing.expect(queue.isEmpty());

    // Enqueue a reaction
    try queue.enqueue(.{ .reaction_type = .upgrade });
    try std.testing.expect(!queue.isEmpty());

    // Clean up
    removeReactionQueue(allocator, element_ptr);

    // Verify queue was removed (getting it again should create a new empty one)
    const new_queue = try getOrCreateReactionQueue(allocator, element_ptr);
    try std.testing.expect(new_queue.isEmpty());

    // The test cleanup happens via deinitThreadLocalState() in defer above
}

test "callback reaction with arguments" {
    const allocator = std.testing.allocator;
    var queue = ReactionQueue.init(allocator);
    defer queue.deinit();

    // Test attribute changed reaction
    try queue.enqueue(.{
        .reaction_type = .callback,
        .callback_type = .attribute_changed,
        .callback_args = .{ .attribute_changed = .{
            .local_name = "class",
            .old_value = "old",
            .new_value = "new",
            .namespace = null,
        } },
    });

    const reaction = queue.dequeue();
    try std.testing.expect(reaction != null);
    try std.testing.expect(reaction.?.reaction_type == .callback);
    try std.testing.expect(reaction.?.callback_type == .attribute_changed);

    const args = reaction.?.callback_args.?.attribute_changed;
    try std.testing.expectEqualStrings("class", args.local_name);
    try std.testing.expectEqualStrings("old", args.old_value.?);
    try std.testing.expectEqualStrings("new", args.new_value.?);
}
