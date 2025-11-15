//! Tests for addEventListener with AbortSignal
//! Spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const event_dispatch = @import("event_dispatch");

const EventTarget = dom.EventTarget;
const Event = dom.Event;
const AbortSignal = dom.AbortSignal;
const AbortController = dom.AbortController;
const AddEventListenerOptions = EventTarget.AddEventListenerOptions;

test "addEventListener with aborted signal does not add listener" {
    const allocator = std.testing.allocator;

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create abort signal and abort it immediately
    var signal = try AbortSignal.init(allocator);
    defer signal.deinit();
    signal.signalAbort(null);

    // Verify signal is aborted
    try std.testing.expect(signal.get_aborted());

    // Try to add listener with aborted signal
    const options = AddEventListenerOptions{
        .capture = false,
        .once = false,
        .passive = null,
        .signal = &signal,
    };

    const callback = @import("webidl").JSValue{ .number = 123.0 };
    try target.call_addEventListener("test", callback, options);

    // Verify listener was NOT added (signal was already aborted)
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}

test "addEventListener with signal removes listener when signal is aborted" {
    const allocator = std.testing.allocator;

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create abort signal (not aborted yet)
    var signal = try AbortSignal.init(allocator);
    defer signal.deinit();

    // Add listener with signal
    const options = AddEventListenerOptions{
        .capture = false,
        .once = false,
        .passive = null,
        .signal = &signal,
    };

    const callback = @import("webidl").JSValue{ .number = 456.0 };
    try target.call_addEventListener("test", callback, options);

    // Verify listener was added
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
    }

    // Abort the signal
    signal.signalAbort(null);

    // Verify listener was removed
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}

test "multiple listeners with same signal are all removed when aborted" {
    const allocator = std.testing.allocator;

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create shared signal
    var signal = try AbortSignal.init(allocator);
    defer signal.deinit();

    // Add multiple listeners with the same signal
    const options = AddEventListenerOptions{
        .capture = false,
        .once = false,
        .passive = null,
        .signal = &signal,
    };

    const callback1 = @import("webidl").JSValue{ .number = 1.0 };
    const callback2 = @import("webidl").JSValue{ .number = 2.0 };
    const callback3 = @import("webidl").JSValue{ .number = 3.0 };

    try target.call_addEventListener("event1", callback1, options);
    try target.call_addEventListener("event2", callback2, options);
    try target.call_addEventListener("event3", callback3, options);

    // Verify all listeners were added
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 3), listeners.len);
    }

    // Abort the shared signal
    signal.signalAbort(null);

    // Verify all listeners were removed
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}

test "listener without signal is not affected by other signal aborts" {
    const allocator = std.testing.allocator;

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create signal
    var signal = try AbortSignal.init(allocator);
    defer signal.deinit();

    // Add listener WITHOUT signal
    const no_signal_options = AddEventListenerOptions{
        .capture = false,
        .once = false,
        .passive = null,
        .signal = null,
    };
    const callback1 = @import("webidl").JSValue{ .number = 100.0 };
    try target.call_addEventListener("event1", callback1, no_signal_options);

    // Add listener WITH signal
    const with_signal_options = AddEventListenerOptions{
        .capture = false,
        .once = false,
        .passive = null,
        .signal = &signal,
    };
    const callback2 = @import("webidl").JSValue{ .number = 200.0 };
    try target.call_addEventListener("event2", callback2, with_signal_options);

    // Verify both listeners were added
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 2), listeners.len);
    }

    // Abort the signal
    signal.signalAbort(null);

    // Verify only the listener WITH signal was removed
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
        try std.testing.expect(std.mem.eql(u8, listeners[0].type, "event1"));
    }
}

test "listener with signal in capture phase is removed when aborted" {
    const allocator = std.testing.allocator;

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create signal
    var signal = try AbortSignal.init(allocator);
    defer signal.deinit();

    // Add listener with signal in capture phase
    const options = AddEventListenerOptions{
        .capture = true,
        .once = false,
        .passive = null,
        .signal = &signal,
    };

    const callback = @import("webidl").JSValue{ .number = 789.0 };
    try target.call_addEventListener("test", callback, options);

    // Verify listener was added
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
        try std.testing.expect(listeners[0].capture);
    }

    // Abort the signal
    signal.signalAbort(null);

    // Verify listener was removed
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}

test "AbortController integration with addEventListener" {
    const allocator = std.testing.allocator;

    // Create event target
    var target = try EventTarget.init(allocator);
    defer target.deinit();

    // Create AbortController
    var controller = try AbortController.init(allocator);
    defer controller.deinit();

    // Add listener with controller's signal
    const options = AddEventListenerOptions{
        .capture = false,
        .once = false,
        .passive = null,
        .signal = &controller.signal,
    };

    const callback = @import("webidl").JSValue{ .number = 999.0 };
    try target.call_addEventListener("test", callback, options);

    // Verify listener was added
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 1), listeners.len);
    }

    // Abort via controller
    controller.call_abort(null);

    // Verify listener was removed
    {
        const listeners = target.getEventListenerList();
        try std.testing.expectEqual(@as(usize, 0), listeners.len);
    }
}
