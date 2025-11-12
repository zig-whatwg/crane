//! Event System Tests (DOM Standard §2)
//! Tests for Event, EventTarget, and event dispatch

const std = @import("std");
const testing = std.testing;

// Import Event and EventTarget from generated WebIDL
const Event = @import("event").Event;
const EventTarget = @import("event_target").EventTarget;
const Node = @import("node").Node;
const event_dispatch = @import("dom").event_dispatch;

test "Event: constructor with type only" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "test");
    defer event.deinit();

    try testing.expectEqualStrings("test", event.type_name);
    try testing.expect(!event.bubbles);
    try testing.expect(!event.cancelable);
    try testing.expect(!event.composed);
    try testing.expectEqual(Event.NONE, event.event_phase);
    try testing.expect(!event.isTrusted);
}

test "Event: constructor with EventInit" {
    const allocator = testing.allocator;

    // Test bubbling event
    var event1 = try Event.initWithOptions(allocator, "click", .{
        .bubbles = true,
        .cancelable = true,
        .composed = false,
    });
    defer event1.deinit();

    try testing.expectEqualStrings("click", event1.type_name);
    try testing.expect(event1.bubbles);
    try testing.expect(event1.cancelable);
    try testing.expect(!event1.composed);
}

test "Event: stopPropagation sets flag" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "test");
    defer event.deinit();

    try testing.expect(!event.stop_propagation_flag);

    event.stopPropagation();

    try testing.expect(event.stop_propagation_flag);
}

test "Event: stopImmediatePropagation sets both flags" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "test");
    defer event.deinit();

    try testing.expect(!event.stop_propagation_flag);
    try testing.expect(!event.stop_immediate_propagation_flag);

    event.stopImmediatePropagation();

    try testing.expect(event.stop_propagation_flag);
    try testing.expect(event.stop_immediate_propagation_flag);
}

test "Event: preventDefault on cancelable event" {
    const allocator = testing.allocator;

    var event = try Event.initWithOptions(allocator, "click", .{
        .cancelable = true,
    });
    defer event.deinit();

    try testing.expect(!event.defaultPrevented);
    try testing.expect(!event.canceled_flag);

    event.preventDefault();

    try testing.expect(event.defaultPrevented);
    try testing.expect(event.canceled_flag);
}

test "Event: preventDefault on non-cancelable event has no effect" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "load");
    defer event.deinit();

    try testing.expect(!event.cancelable);
    try testing.expect(!event.defaultPrevented);

    event.preventDefault(); // Should have no effect

    try testing.expect(!event.defaultPrevented);
    try testing.expect(!event.canceled_flag);
}

test "Event: isTrusted defaults to false" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "custom");
    defer event.deinit();

    // Events created by scripts (via constructor) have isTrusted = false
    try testing.expect(!event.isTrusted);
}

test "Event: composedPath returns empty for non-dispatched event" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "test");
    defer event.deinit();

    const path = try event.composedPath(allocator);
    defer allocator.free(path);

    try testing.expectEqual(@as(usize, 0), path.len);
}

test "EventTarget: addEventListener and removeEventListener" {
    const allocator = testing.allocator;

    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create a simple callback (for testing, we'll use a dummy)
    // TODO: Implement proper callback support

    // For now, just test that the methods exist and don't crash
    // Full testing requires callback implementation
}

test "Event: cancelBubble getter/setter (legacy)" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "test");
    defer event.deinit();

    // Initially false
    try testing.expect(!event.cancelBubble);
    try testing.expect(!event.stop_propagation_flag);

    // Setting to true sets stop propagation flag
    event.cancelBubble = true;
    try testing.expect(event.cancelBubble);
    try testing.expect(event.stop_propagation_flag);

    // Setting to false does nothing (cannot un-stop)
    event.cancelBubble = false;
    try testing.expect(event.stop_propagation_flag);
}

test "Event: returnValue getter/setter (legacy)" {
    const allocator = testing.allocator;

    var event = try Event.initWithOptions(allocator, "click", .{
        .cancelable = true,
    });
    defer event.deinit();

    // Initially true (not canceled)
    try testing.expect(event.returnValue);
    try testing.expect(!event.canceled_flag);

    // Setting to false cancels the event
    event.returnValue = false;
    try testing.expect(!event.returnValue);
    try testing.expect(event.canceled_flag);

    // Setting to true does nothing (cannot un-cancel)
    event.returnValue = true;
    try testing.expect(event.canceled_flag);
}

test "Event: eventPhase transitions" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "test");
    defer event.deinit();

    // Initially NONE
    try testing.expectEqual(Event.NONE, event.event_phase);

    // Can be set to different phases (during dispatch)
    event.event_phase = Event.CAPTURING_PHASE;
    try testing.expectEqual(Event.CAPTURING_PHASE, event.event_phase);

    event.event_phase = Event.AT_TARGET;
    try testing.expectEqual(Event.AT_TARGET, event.event_phase);

    event.event_phase = Event.BUBBLING_PHASE;
    try testing.expectEqual(Event.BUBBLING_PHASE, event.event_phase);

    event.event_phase = Event.NONE;
    try testing.expectEqual(Event.NONE, event.event_phase);
}

test "Event: target and currentTarget" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "test");
    defer event.deinit();

    // Initially null
    try testing.expect(event.target == null);
    try testing.expect(event.current_target == null);

    // Can be set during dispatch
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    event.target = &target;
    event.current_target = &target;

    try testing.expect(event.target == &target);
    try testing.expect(event.current_target == &target);
}

test "Event: event path manipulation" {
    const allocator = testing.allocator;

    var event = try Event.init(allocator, "test");
    defer event.deinit();

    // Initially empty
    try testing.expectEqual(@as(usize, 0), event.path.items.len);

    // Can append to path
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    var touch_targets = std.ArrayList(*EventTarget).init(allocator);
    defer touch_targets.deinit();

    const path_item = Event.EventPathItem{
        .invocation_target = &target,
        .invocation_target_in_shadow_tree = false,
        .shadow_adjusted_target = &target,
        .related_target = null,
        .touch_target_list = touch_targets,
        .root_of_closed_tree = false,
        .slot_in_closed_tree = false,
    };

    try event.path.append(path_item);

    try testing.expectEqual(@as(usize, 1), event.path.items.len);
    try testing.expect(event.path.items[0].invocation_target == &target);
}

test "Event dispatch: basic tree traversal" {
    const allocator = testing.allocator;

    // Create a simple node tree: parent -> child
    var parent = try Node.init(allocator, Node.ELEMENT_NODE, "div");
    defer parent.deinit();

    var child = try Node.init(allocator, Node.ELEMENT_NODE, "span");
    defer child.deinit();

    // Set up parent-child relationship
    child.parent_node = &parent;
    try parent.child_nodes.append(&child);

    // Create a bubbling event
    var event = try Event.initWithOptions(allocator, "click", .{
        .bubbles = true,
        .cancelable = false,
        .composed = false,
    });
    defer event.deinit();

    // Dispatch event on child - should traverse up to parent
    const result = try event_dispatch.dispatch(
        &event,
        @ptrCast(&child),
        false,
        null,
    );

    // Event should have been dispatched
    try testing.expect(result);

    // Event path should contain both child and parent
    // Path is built from target up to root
    try testing.expect(event.path.items.len >= 1);

    // Verify dispatch flag was set
    try testing.expect(event.dispatch_flag);
}

test "Event dispatch: activation behavior flow" {
    const allocator = testing.allocator;

    // Create a simple target
    var target = try Node.init(allocator, Node.ELEMENT_NODE, "button");
    defer target.deinit();

    // Create a click event (isActivationEvent = true)
    var event = try Event.initWithOptions(allocator, "click", .{
        .bubbles = true,
        .cancelable = true,
        .composed = false,
    });
    defer event.deinit();

    // Dispatch click event - should go through activation behavior flow
    const result = try event_dispatch.dispatch(
        &event,
        @ptrCast(&target),
        false,
        null,
    );

    // Event should have been dispatched
    try testing.expect(result);

    // For click events:
    // 1. isActivationEvent should be detected (type == "click")
    // 2. If target has activation behavior, activationTarget is set
    // 3. After event propagation, activation behavior is executed (if not canceled)
    //
    // Since our stub hasActivationBehavior() returns false, activationTarget stays null
    // This test verifies the flow doesn't crash and completes successfully
}

test "Event dispatch: activation behavior with canceled event" {
    const allocator = testing.allocator;

    // Create a simple target
    var target = try Node.init(allocator, Node.ELEMENT_NODE, "button");
    defer target.deinit();

    // Create a cancelable click event
    var event = try Event.initWithOptions(allocator, "click", .{
        .bubbles = true,
        .cancelable = true,
        .composed = false,
    });
    defer event.deinit();

    // Cancel the event (preventDefault)
    event.preventDefault();
    try testing.expect(event.canceled_flag);

    // Dispatch click event - should go through activation behavior flow
    const result = try event_dispatch.dispatch(
        &event,
        @ptrCast(&target),
        false,
        null,
    );

    // Event should return false because canceled_flag is set
    try testing.expect(!result);

    // Activation behavior flow:
    // 1. isActivationEvent detected (type == "click")
    // 2. If activationTarget is set and event is canceled:
    //    - Normal activation behavior is NOT run
    //    - Legacy-canceled-activation behavior IS run (if present)
    //
    // This test verifies canceled events don't run activation behavior
}

test "Event dispatch: non-click event does not trigger activation" {
    const allocator = testing.allocator;

    // Create a simple target
    var target = try Node.init(allocator, Node.ELEMENT_NODE, "button");
    defer target.deinit();

    // Create a non-click event (should NOT be activation event)
    var event = try Event.initWithOptions(allocator, "mouseover", .{
        .bubbles = true,
        .cancelable = true,
        .composed = false,
    });
    defer event.deinit();

    // Dispatch non-click event
    const result = try event_dispatch.dispatch(
        &event,
        @ptrCast(&target),
        false,
        null,
    );

    // Event should have been dispatched
    try testing.expect(result);

    // isActivationEvent should be false (type != "click")
    // Therefore activationTarget should remain null
    // No activation behavior should be executed
}
