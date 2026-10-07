//! These queues may own engine values. Run their value-type checks in the
//! html test executable, which links the adapter, not html_core's unit binary.
const std = @import("std");
const runtime = @import("runtime");
const custom_elements = @import("html").custom_elements;
const ReactionQueue = custom_elements.ReactionQueue;
const ReactionsStack = custom_elements.ReactionsStack;
const ElementReactionQueues = custom_elements.ElementReactionQueues;
const getOrCreateReactionQueue = custom_elements.getOrCreateReactionQueue;
const removeReactionQueue = custom_elements.removeReactionQueue;

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
    var queues = ElementReactionQueues.init(allocator);
    defer queues.deinit();

    // Create a mock element Instance
    // Note: In real code, Instance is created via runtime.Instance.init()
    // For testing, we create a minimal struct that can be used as a key
    var mock_state: u8 = 0;
    const mock_vtable = runtime.VTable{
        .name = "<mock-element>",
        .deinit = null,
        .methods_ptr = &.{},
    };
    var mock_instance = runtime.Instance{
        .vtable = &mock_vtable,
        .state = @ptrCast(&mock_state),
        .ctx = undefined,
    };
    const element_ptr: *runtime.Instance = &mock_instance;

    // Get or create queue for element
    const queue = try getOrCreateReactionQueue(&queues, element_ptr);
    try std.testing.expect(queue.isEmpty());

    // Enqueue a reaction
    try queue.enqueue(.{ .reaction_type = .upgrade });
    try std.testing.expect(!queue.isEmpty());

    // Clean up
    removeReactionQueue(&queues, element_ptr);

    // Verify queue was removed (getting it again should create a new empty one)
    const new_queue = try getOrCreateReactionQueue(&queues, element_ptr);
    try std.testing.expect(new_queue.isEmpty());
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
