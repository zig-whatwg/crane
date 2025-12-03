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

// Import the WebIDL-based CustomElementRegistry implementation
const webidl_impls = @import("webidl").impls;
const CustomElementRegistryImpl = webidl_impls.CustomElementRegistry;
const CustomElementDefinition = CustomElementRegistryImpl.CustomElementDefinition;

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
    reactions: std.ArrayList(Reaction),
    allocator: Allocator,

    pub fn init(allocator: Allocator) ReactionQueue {
        return .{
            .reactions = std.ArrayList(Reaction).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ReactionQueue) void {
        self.reactions.deinit();
    }

    pub fn enqueue(self: *ReactionQueue, reaction: Reaction) !void {
        try self.reactions.append(reaction);
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
pub const ElementQueue = std.ArrayList(*anyopaque); // *Element opaque pointers

/// Custom element reactions stack
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element-reactions-stack
pub const ReactionsStack = struct {
    stack: std.ArrayList(ElementQueue),
    backup_queue: ElementQueue,
    processing_backup: bool = false,
    allocator: Allocator,

    pub fn init(allocator: Allocator) ReactionsStack {
        return .{
            .stack = std.ArrayList(ElementQueue).init(allocator),
            .backup_queue = ElementQueue.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ReactionsStack) void {
        for (self.stack.items) |*queue| {
            queue.deinit();
        }
        self.stack.deinit();
        self.backup_queue.deinit();
    }

    pub fn push(self: *ReactionsStack) !void {
        const queue = ElementQueue.init(self.allocator);
        try self.stack.append(queue);
    }

    pub fn pop(self: *ReactionsStack) ?ElementQueue {
        return self.stack.popOrNull();
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

/// Get or initialize the reactions stack for the current agent
pub fn getReactionsStack(allocator: Allocator) *ReactionsStack {
    if (reactions_stack == null) {
        reactions_stack = ReactionsStack.init(allocator);
    }
    return &reactions_stack.?;
}

/// Enqueue an element on the appropriate element queue
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-an-element-on-the-appropriate-element-queue
pub fn enqueueElementOnAppropriateQueue(allocator: Allocator, element: *anyopaque) !void {
    const stack = getReactionsStack(allocator);

    // Step 2: If stack is empty, use backup queue
    if (stack.isEmpty()) {
        try stack.backup_queue.append(element);

        // Step 2.2: If already processing backup, return
        if (stack.processing_backup) return;

        // Step 2.3: Set processing flag
        stack.processing_backup = true;

        // Step 2.4: Queue a microtask to process backup queue
        // TODO: Integrate with event loop microtask queue
        // For now, process immediately (synchronous fallback)
        invokeCustomElementReactions(&stack.backup_queue);
        stack.processing_backup = false;
    } else {
        // Step 3: Add to current element queue
        if (stack.currentElementQueue()) |queue| {
            try queue.append(element);
        }
    }
}

/// Enqueue a custom element callback reaction
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-a-custom-element-callback-reaction
pub fn enqueueCustomElementCallbackReaction(
    element: anytype,
    callback_name: []const u8,
    args: anytype,
) void {
    _ = element;
    _ = callback_name;
    _ = args;

    // TODO: Implement full callback reaction queueing:
    // 1. Get element's custom element definition
    // 2. Get callback from definition's lifecycle callbacks
    // 3. Handle connectedMoveCallback fallback
    // 4. Check observedAttributes for attributeChangedCallback
    // 5. Add callback reaction to element's reaction queue
    // 6. Enqueue element on appropriate queue

    // For now, this is a no-op as custom elements aren't fully integrated
}

/// Enqueue a custom element upgrade reaction
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#enqueue-a-custom-element-upgrade-reaction
pub fn enqueueCustomElementUpgradeReaction(element: *anyopaque, definition: *CustomElementDefinition) !void {
    _ = element;
    _ = definition;

    // TODO: Implement upgrade reaction queueing:
    // 1. Add upgrade reaction to element's reaction queue
    // 2. Enqueue element on appropriate queue

    // For now, this is a no-op
}

/// Invoke custom element reactions in an element queue
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#invoke-custom-element-reactions
pub fn invokeCustomElementReactions(queue: *ElementQueue) void {
    while (queue.items.len > 0) {
        const element = queue.orderedRemove(0);
        _ = element;

        // TODO: Get element's reaction queue and process each reaction
        // For each reaction:
        //   - upgrade reaction: call upgradeElement()
        //   - callback reaction: invoke the callback function
    }
}

/// Run custom element adoption steps
/// Spec: https://html.spec.whatwg.org/#concept-try-upgrade (referenced in adopt)
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

    // TODO: Implement adoption steps:
    // 1. Check if element is custom
    // 2. Enqueue adoptedCallback if defined
}

/// Enqueue custom element adoptedCallback
/// Spec: https://html.spec.whatwg.org/#concept-custom-element-adopted-callback
pub fn enqueueAdoptedCallback(
    element: anytype,
    old_document: anytype,
    new_document: anytype,
) void {
    _ = element;
    _ = old_document;
    _ = new_document;

    // TODO: Implement adoptedCallback reaction
}

/// Enqueue custom element connectedMoveCallback
/// Spec: https://html.spec.whatwg.org/#custom-element-reactions (connectedMoveCallback)
///
/// Called when a custom element is moved within the tree and remains connected
pub fn enqueueConnectedMoveCallback(
    element: anytype,
    old_parent: anytype,
) void {
    _ = element;
    _ = old_parent;

    // TODO: Implement connectedMoveCallback reaction
}

/// Moving steps callback for custom elements
/// This is registered with the DOM mutation system via registerMovingStepsCallback
/// Spec: https://dom.spec.whatwg.org/#concept-node-move step 24.2
fn customElementMovingSteps(node: *Node, old_parent: ?*Node) void {
    const new_parent = node.parent_node orelse return;
    _ = new_parent;
    _ = old_parent;

    // TODO: Implement when custom elements are fully integrated
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
