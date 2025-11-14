//! Tests for DOM event dispatch with once flag
//! Spec: https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke

const std = @import("std");
const dom = @import("dom");
const dom_types = @import("dom_types");
const infra = @import("infra");
const webidl = @import("webidl");

const event_dispatch = @import("event_dispatch");

const EventTarget = dom_types.EventTarget;
const Event = dom_types.Event;
const AddEventListenerOptions = EventTarget.AddEventListenerOptions;

// Test state for callback tracking
var callback_count: usize = 0;

fn resetCallbackCount() void {
    callback_count = 0;
}

test "addEventListener with once=true removes listener after first dispatch" {
    const allocator = std.testing.allocator;
    resetCallbackCount();

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create event
    var event = try Event.init(allocator, "test");
    defer event.deinit();

    // Add listener with once=true
    const options = AddEventListenerOptions{
        .capture = false,
        .once = true,
        .passive = null,
        .signal = null,
    };

    // Use a test callback marker
    const test_callback = @import("webidl").JSValue{ .number = 123.0 };

    try target.call_addEventListener("test", test_callback, options);

    // Verify listener was added
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
        try std.testing.expect(listeners[0].once);
    }

    // Dispatch event first time
    _ = try event_dispatch.dispatch(&event, &target, false, null);

    // Verify listener was removed after dispatch
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }

    // Dispatch event second time - should have no effect (no listeners)
    _ = try event_dispatch.dispatch(&event, &target, false, null);

    // Verify still no listeners
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}

test "addEventListener with once=false keeps listener after dispatch" {
    const allocator = std.testing.allocator;
    resetCallbackCount();

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create event
    var event = try Event.init(allocator, "test");
    defer event.deinit();

    // Add listener with once=false (default)
    const options = AddEventListenerOptions{
        .capture = false,
        .once = false,
        .passive = null,
        .signal = null,
    };

    const test_callback = @import("webidl").JSValue{ .number = 456.0 };

    try target.call_addEventListener("test", test_callback, options);

    // Verify listener was added
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
        try std.testing.expect(!listeners[0].once);
    }

    // Dispatch event first time
    _ = try event_dispatch.dispatch(&event, &target, false, null);

    // Verify listener is still there after dispatch
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
    }

    // Dispatch event second time
    _ = try event_dispatch.dispatch(&event, &target, false, null);

    // Verify listener is still there
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
    }
}

test "multiple once listeners are removed independently" {
    const allocator = std.testing.allocator;
    resetCallbackCount();

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Add two once listeners for different event types
    const once_options = AddEventListenerOptions{
        .capture = false,
        .once = true,
        .passive = null,
        .signal = null,
    };

    const callback1 = @import("webidl").JSValue{ .number = 1.0 };
    const callback2 = @import("webidl").JSValue{ .number = 2.0 };

    try target.call_addEventListener("event1", callback1, once_options);
    try target.call_addEventListener("event2", callback2, once_options);

    // Verify both listeners were added
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 2), listeners.len);
    }

    // Dispatch event1
    var event1 = try Event.init(allocator, "event1");
    defer event1.deinit();
    _ = try event_dispatch.dispatch(&event1, &target, false, null);

    // Verify only event1 listener was removed
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
        try std.testing.expect(std.mem.eql(u8, listeners[0].type, "event2"));
    }

    // Dispatch event2
    var event2 = try Event.init(allocator, "event2");
    defer event2.deinit();
    _ = try event_dispatch.dispatch(&event2, &target, false, null);

    // Verify both listeners are now removed
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}

test "once listener removed even if stopPropagation is called" {
    const allocator = std.testing.allocator;
    resetCallbackCount();

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Add once listener
    const once_options = AddEventListenerOptions{
        .capture = false,
        .once = true,
        .passive = null,
        .signal = null,
    };

    const callback = @import("webidl").JSValue{ .number = 789.0 };

    try target.call_addEventListener("test", callback, once_options);

    // Create event and call stopPropagation
    var event = try Event.init(allocator, "test");
    defer event.deinit();
    event.stopPropagation();

    // Dispatch event
    _ = try event_dispatch.dispatch(&event, &target, false, null);

    // Verify listener was removed even though stopPropagation was called
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}

test "once listener in capture phase is removed" {
    const allocator = std.testing.allocator;
    resetCallbackCount();

    // Create parent and child targets
    var parent = try EventTarget.init(allocator);
    defer parent.deinit();

    var child = try EventTarget.init(allocator);
    defer child.deinit();

    // Add once listener in capture phase on parent
    const capture_once_options = AddEventListenerOptions{
        .capture = true,
        .once = true,
        .passive = null,
        .signal = null,
    };

    const callback = @import("webidl").JSValue{ .number = 999.0 };

    try parent.call_addEventListener("test", callback, capture_once_options);

    // Verify listener was added
    {
        const listeners = parent.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
        try std.testing.expect(listeners[0].capture);
        try std.testing.expect(listeners[0].once);
    }

    // Dispatch event
    var event = try Event.init(allocator, "test");
    defer event.deinit();
    _ = try event_dispatch.dispatch(&event, &parent, false, null);

    // Verify listener was removed after dispatch
    {
        const listeners = parent.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}
