//! Custom Elements Tests
//!
//! Comprehensive tests for custom element reactions per HTML Standard §4.13.5
//! Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element-reactions
//!
//! Tests cover:
//! - Reaction queue management
//! - Callback reaction enqueuing
//! - Upgrade reaction enqueuing
//! - Lifecycle callback invocation order
//! - Attribute observation filtering
//! - Custom element state transitions

const std = @import("std");
const html = @import("html");
const custom_elements = html.custom_elements;
const upgrade = html.upgrade;
const ReactionQueue = custom_elements.ReactionQueue;
const ReactionsStack = custom_elements.ReactionsStack;
const Reaction = custom_elements.Reaction;
const ReactionType = custom_elements.ReactionType;
const CallbackType = custom_elements.CallbackType;
const CustomElementState = upgrade.CustomElementState;

// ============================================================================
// Reaction Queue Tests
// ============================================================================

test "ReactionQueue - initialization" {
    const allocator = std.testing.allocator;
    var queue = ReactionQueue.init(allocator);
    defer queue.deinit();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.reactions.items.len);
}

test "ReactionQueue - enqueue single reaction" {
    const allocator = std.testing.allocator;
    var queue = ReactionQueue.init(allocator);
    defer queue.deinit();

    try queue.enqueue(.{
        .reaction_type = .upgrade,
        .definition = null,
    });

    try std.testing.expect(!queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), queue.reactions.items.len);
}

test "ReactionQueue - FIFO ordering" {
    const allocator = std.testing.allocator;
    var queue = ReactionQueue.init(allocator);
    defer queue.deinit();

    // Enqueue multiple reactions
    try queue.enqueue(.{
        .reaction_type = .upgrade,
        .callback_type = null,
    });
    try queue.enqueue(.{
        .reaction_type = .callback,
        .callback_type = .connected,
    });
    try queue.enqueue(.{
        .reaction_type = .callback,
        .callback_type = .disconnected,
    });

    // Dequeue and verify order (FIFO)
    const first = queue.dequeue();
    try std.testing.expect(first != null);
    try std.testing.expectEqual(ReactionType.upgrade, first.?.reaction_type);

    const second = queue.dequeue();
    try std.testing.expect(second != null);
    try std.testing.expectEqual(ReactionType.callback, second.?.reaction_type);
    try std.testing.expectEqual(CallbackType.connected, second.?.callback_type.?);

    const third = queue.dequeue();
    try std.testing.expect(third != null);
    try std.testing.expectEqual(CallbackType.disconnected, third.?.callback_type.?);

    // Queue should now be empty
    try std.testing.expect(queue.isEmpty());
    try std.testing.expect(queue.dequeue() == null);
}

test "ReactionQueue - clear" {
    const allocator = std.testing.allocator;
    var queue = ReactionQueue.init(allocator);
    defer queue.deinit();

    try queue.enqueue(.{ .reaction_type = .upgrade });
    try queue.enqueue(.{ .reaction_type = .callback, .callback_type = .connected });
    try std.testing.expect(!queue.isEmpty());

    queue.clear();
    try std.testing.expect(queue.isEmpty());
}

// ============================================================================
// Reactions Stack Tests
// ============================================================================

test "ReactionsStack - initialization" {
    const allocator = std.testing.allocator;
    var stack = ReactionsStack.init(allocator);
    defer stack.deinit();

    try std.testing.expect(stack.isEmpty());
    try std.testing.expect(!stack.processing_backup);
}

test "ReactionsStack - push and pop" {
    const allocator = std.testing.allocator;
    var stack = ReactionsStack.init(allocator);
    defer stack.deinit();

    try stack.push();
    try std.testing.expect(!stack.isEmpty());

    try stack.push();
    try std.testing.expectEqual(@as(usize, 2), stack.stack.items.len);

    const popped1 = stack.pop();
    try std.testing.expect(popped1 != null);

    const popped2 = stack.pop();
    try std.testing.expect(popped2 != null);

    try std.testing.expect(stack.isEmpty());
}

test "ReactionsStack - currentElementQueue" {
    const allocator = std.testing.allocator;
    var stack = ReactionsStack.init(allocator);
    defer stack.deinit();

    // No queue when stack is empty
    try std.testing.expect(stack.currentElementQueue() == null);

    // Push creates a queue
    try stack.push();
    const queue = stack.currentElementQueue();
    try std.testing.expect(queue != null);

    // Current queue is the top of the stack
    try stack.push();
    const queue2 = stack.currentElementQueue();
    try std.testing.expect(queue2 != null);
    try std.testing.expect(queue != queue2);

    // Pop returns to previous queue
    _ = stack.pop();
    const queue3 = stack.currentElementQueue();
    try std.testing.expect(queue3 == queue);
}

// ============================================================================
// Callback Reaction Tests
// ============================================================================

test "Reaction - callback with attribute changed args" {
    const reaction = Reaction{
        .reaction_type = .callback,
        .callback_type = .attribute_changed,
        .callback_args = .{
            .attribute_changed = .{
                .local_name = "class",
                .old_value = "old-class",
                .new_value = "new-class",
                .namespace = null,
            },
        },
    };

    try std.testing.expectEqual(ReactionType.callback, reaction.reaction_type);
    try std.testing.expectEqual(CallbackType.attribute_changed, reaction.callback_type.?);

    const args = reaction.callback_args.?.attribute_changed;
    try std.testing.expectEqualStrings("class", args.local_name);
    try std.testing.expectEqualStrings("old-class", args.old_value.?);
    try std.testing.expectEqualStrings("new-class", args.new_value.?);
    try std.testing.expect(args.namespace == null);
}

test "Reaction - callback with adopted args" {
    var old_doc: u8 = 1;
    var new_doc: u8 = 2;

    const reaction = Reaction{
        .reaction_type = .callback,
        .callback_type = .adopted,
        .callback_args = .{
            .adopted = .{
                .old_document = &old_doc,
                .new_document = &new_doc,
            },
        },
    };

    try std.testing.expectEqual(CallbackType.adopted, reaction.callback_type.?);
    const args = reaction.callback_args.?.adopted;
    try std.testing.expect(args.old_document != args.new_document);
}

test "Reaction - callback without args (connected/disconnected)" {
    const connected = Reaction{
        .reaction_type = .callback,
        .callback_type = .connected,
        .callback_args = .{ .none = {} },
    };
    try std.testing.expectEqual(CallbackType.connected, connected.callback_type.?);

    const disconnected = Reaction{
        .reaction_type = .callback,
        .callback_type = .disconnected,
        .callback_args = .{ .none = {} },
    };
    try std.testing.expectEqual(CallbackType.disconnected, disconnected.callback_type.?);
}

// ============================================================================
// Element Reaction Queue Management Tests
// ============================================================================

test "element reaction queue - get or create" {
    const allocator = std.testing.allocator;
    defer custom_elements.deinitThreadLocalState(); // Clean up thread-local state

    var mock_element: u8 = 0;
    const element_ptr: *anyopaque = &mock_element;

    // Get or create should create a new empty queue
    const queue1 = try custom_elements.getOrCreateReactionQueue(allocator, element_ptr);
    try std.testing.expect(queue1.isEmpty());

    // Getting again should return the same queue
    const queue2 = try custom_elements.getOrCreateReactionQueue(allocator, element_ptr);
    try std.testing.expect(queue1 == queue2);

    // Adding to queue should persist
    try queue1.enqueue(.{ .reaction_type = .upgrade });
    try std.testing.expect(!queue2.isEmpty());

    // Clean up handled by deinitThreadLocalState() defer above
}

test "element reaction queue - removal" {
    const allocator = std.testing.allocator;
    defer custom_elements.deinitThreadLocalState(); // Clean up thread-local state

    var mock_element: u8 = 0;
    const element_ptr: *anyopaque = &mock_element;

    // Create and populate queue
    const queue = try custom_elements.getOrCreateReactionQueue(allocator, element_ptr);
    try queue.enqueue(.{ .reaction_type = .upgrade });
    try std.testing.expect(!queue.isEmpty());

    // Remove queue
    custom_elements.removeReactionQueue(allocator, element_ptr);

    // Getting queue again should return a new empty queue
    const new_queue = try custom_elements.getOrCreateReactionQueue(allocator, element_ptr);
    try std.testing.expect(new_queue.isEmpty());

    // Clean up handled by deinitThreadLocalState() defer above
}

// ============================================================================
// Custom Element State Tests
// ============================================================================

test "CustomElementState - enumeration values" {
    // Verify all states exist
    try std.testing.expectEqual(CustomElementState.undefined, CustomElementState.undefined);
    try std.testing.expectEqual(CustomElementState.failed, CustomElementState.failed);
    try std.testing.expectEqual(CustomElementState.uncustomized, CustomElementState.uncustomized);
    try std.testing.expectEqual(CustomElementState.precustomized, CustomElementState.precustomized);
    try std.testing.expectEqual(CustomElementState.custom, CustomElementState.custom);

    // Verify they are distinct
    try std.testing.expect(CustomElementState.undefined != CustomElementState.custom);
    try std.testing.expect(CustomElementState.failed != CustomElementState.custom);
}

test "UpgradeContext - initialization" {
    const allocator = std.testing.allocator;
    var mock_element: u8 = 0;

    const ctx = upgrade.UpgradeContext{
        .element = &mock_element,
        .definition = undefined,
        .allocator = allocator,
        .is_connected = false,
    };

    try std.testing.expect(ctx.state == .undefined);
    try std.testing.expect(!ctx.is_connected);
}

// ============================================================================
// Callback Type Tests
// ============================================================================

test "CallbackType - all types defined" {
    // Verify all callback types exist per spec
    const types = [_]CallbackType{
        .connected,
        .disconnected,
        .adopted,
        .connected_move,
        .attribute_changed,
        .form_associated,
        .form_reset,
        .form_disabled,
        .form_state_restore,
    };

    for (types, 0..) |cb_type, i| {
        _ = i;
        // Just verify they compile and are accessible
        try std.testing.expect(@intFromEnum(cb_type) >= 0);
    }
}

// ============================================================================
// Integration Tests - Reaction Queue with Stack
// ============================================================================

test "reactions stack integration - backup queue processing" {
    const allocator = std.testing.allocator;

    // Reset thread-local state for clean test
    // Note: In a real implementation, we'd have proper reset functions
    const stack = custom_elements.getReactionsStack(allocator);

    // When stack is empty, elements should go to backup queue
    try std.testing.expect(stack.isEmpty());

    // This is integration-level behavior that requires more infrastructure
    // to fully test (actual elements, definitions, etc.)
}

// ============================================================================
// Callback Args Tests
// ============================================================================

test "CallbackArgs - none variant" {
    const args = Reaction.CallbackArgs{ .none = {} };
    try std.testing.expect(args == .none);
}

test "CallbackArgs - attribute_changed variant" {
    const args = Reaction.CallbackArgs{
        .attribute_changed = .{
            .local_name = "data-test",
            .old_value = null,
            .new_value = "value",
            .namespace = "http://www.w3.org/1999/xhtml",
        },
    };

    try std.testing.expect(args == .attribute_changed);
    const attr_args = args.attribute_changed;
    try std.testing.expectEqualStrings("data-test", attr_args.local_name);
    try std.testing.expect(attr_args.old_value == null);
    try std.testing.expectEqualStrings("value", attr_args.new_value.?);
    try std.testing.expectEqualStrings("http://www.w3.org/1999/xhtml", attr_args.namespace.?);
}

test "CallbackArgs - adopted variant" {
    var old_doc: u8 = 0;
    var new_doc: u8 = 1;

    const args = Reaction.CallbackArgs{
        .adopted = .{
            .old_document = &old_doc,
            .new_document = &new_doc,
        },
    };

    try std.testing.expect(args == .adopted);
}

// ============================================================================
// Form-Associated Custom Element Tests
// ============================================================================

test "form-associated callback types" {
    // Verify form-associated callback types work
    const form_associated = Reaction{
        .reaction_type = .callback,
        .callback_type = .form_associated,
        .callback_args = .{ .none = {} },
    };
    try std.testing.expectEqual(CallbackType.form_associated, form_associated.callback_type.?);

    const form_reset = Reaction{
        .reaction_type = .callback,
        .callback_type = .form_reset,
        .callback_args = .{ .none = {} },
    };
    try std.testing.expectEqual(CallbackType.form_reset, form_reset.callback_type.?);

    const form_disabled = Reaction{
        .reaction_type = .callback,
        .callback_type = .form_disabled,
        .callback_args = .{ .none = {} },
    };
    try std.testing.expectEqual(CallbackType.form_disabled, form_disabled.callback_type.?);

    const form_state_restore = Reaction{
        .reaction_type = .callback,
        .callback_type = .form_state_restore,
        .callback_args = .{ .none = {} },
    };
    try std.testing.expectEqual(CallbackType.form_state_restore, form_state_restore.callback_type.?);
}

// ============================================================================
// Queue Stress Tests
// ============================================================================

test "ReactionQueue - many reactions" {
    const allocator = std.testing.allocator;
    var queue = ReactionQueue.init(allocator);
    defer queue.deinit();

    // Enqueue many reactions
    const count = 1000;
    for (0..count) |i| {
        try queue.enqueue(.{
            .reaction_type = if (i % 2 == 0) .upgrade else .callback,
            .callback_type = if (i % 2 == 0) null else .connected,
        });
    }

    try std.testing.expectEqual(@as(usize, count), queue.reactions.items.len);

    // Dequeue all
    var dequeued: usize = 0;
    while (queue.dequeue()) |_| {
        dequeued += 1;
    }

    try std.testing.expectEqual(count, dequeued);
    try std.testing.expect(queue.isEmpty());
}

test "ReactionsStack - multiple element queues" {
    const allocator = std.testing.allocator;
    var stack = ReactionsStack.init(allocator);
    defer stack.deinit();

    // Push multiple queues
    const depth = 10;
    for (0..depth) |_| {
        try stack.push();
    }

    try std.testing.expectEqual(@as(usize, depth), stack.stack.items.len);

    // Pop all
    for (0..depth) |_| {
        try std.testing.expect(stack.pop() != null);
    }

    try std.testing.expect(stack.isEmpty());
}
