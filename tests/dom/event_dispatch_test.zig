//! DOM §2.3 / §2.9 - Event initialization and dispatch invariants.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-event-dispatch
//!
//! These pin the two invariants that made `dom/events/` look like a phase bug
//! when it was really a string-ownership bug and a missing flag:
//!
//!   1. `initEvent` stores a type string the Event OWNS. The WebIDL conversion
//!      layer frees the DOMString it hands an impl as soon as the call returns,
//!      so storing the argument makes `event.type` read freed memory - and a
//!      dispatch that matches listeners on `event.type` then matches nothing.
//!   2. `createEvent` leaves the initialized flag UNSET, and `dispatchEvent`
//!      throws InvalidStateError when it is.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const webidl = @import("webidl");

const OptBool = webidl.Opt(bool);

/// The event's initialized flag, from its dispatch state (dom.event_dispatch,
/// which Event installs): an event with no state has never been initialized.
fn initialized(event: *runtime.Instance) bool {
    const state = dom.event_dispatch.of(event) orelse return false;
    return state.initialized_flag;
}

fn newEvent(ctx: runtime.Context, @"type": []const u8) !*runtime.Instance {
    return interfaces.Event.call_constructor(
        ctx,
        runtime.DOMString.initInterned(@"type"),
        .{ .was_passed = false, .value = undefined },
    );
}

test "initEvent stores a type string the Event owns" {
    const allocator = std.testing.allocator;

    // Instance.init draws from the process-wide slab and arena; without
    // these the first allocation aborts. tests/runtime does the same.
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.createNullContext(allocator);
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const event = try newEvent(ctx, "");
    defer interfaces.Event.deinit(event);

    // The conversion layer hands an impl a heap DOMString and frees it the
    // moment the call returns. Model that exactly.
    var caller_owned = try runtime.DOMString.initDupe(allocator, "type");
    try interfaces.Event.call_initEvent(
        event,
        caller_owned,
        OptBool.passed(false),
        OptBool.passed(false),
    );
    caller_owned.deinit(allocator);

    // If initEvent aliased the caller's buffer this reads freed memory, and
    // Event.deinit then double-frees it.
    const observed = try interfaces.Event.get_type(event);
    try std.testing.expectEqualStrings("type", observed.asSlice());
}

test "initEvent releases the type string it replaces" {
    const allocator = std.testing.allocator;

    // Instance.init draws from the process-wide slab and arena; without
    // these the first allocation aborts. tests/runtime does the same.
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.createNullContext(allocator);
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    // A non-empty constructor type is cloned into the event, so the second
    // initEvent has something to release. Leaking it fails under
    // std.testing.allocator.
    const event = try newEvent(ctx, "first");
    defer interfaces.Event.deinit(event);

    var second = try runtime.DOMString.initDupe(allocator, "second");
    defer second.deinit(allocator);
    try interfaces.Event.call_initEvent(event, second, OptBool.notPassed(), OptBool.notPassed());

    var third = try runtime.DOMString.initDupe(allocator, "third");
    defer third.deinit(allocator);
    try interfaces.Event.call_initEvent(event, third, OptBool.notPassed(), OptBool.notPassed());

    const observed = try interfaces.Event.get_type(event);
    try std.testing.expectEqualStrings("third", observed.asSlice());
}

test "the constructor sets the initialized flag" {
    const allocator = std.testing.allocator;

    // Instance.init draws from the process-wide slab and arena; without
    // these the first allocation aborts. tests/runtime does the same.
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.createNullContext(allocator);
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const event = try newEvent(ctx, "x");
    defer interfaces.Event.deinit(event);

    try std.testing.expect(initialized(event));
}

test "createEvent leaves the initialized flag unset until initEvent" {
    const allocator = std.testing.allocator;

    // Instance.init draws from the process-wide slab and arena; without
    // these the first allocation aborts. tests/runtime does the same.
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.createNullContext(allocator);
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    // https://dom.spec.whatwg.org/#dom-document-createevent step 8:
    // "Unset event's initialized flag."
    const event = try newEvent(ctx, "");
    defer interfaces.Event.deinit(event);
    dom.event_dispatch.of(event).?.initialized_flag = false;

    try std.testing.expect(!initialized(event));
    try std.testing.expectEqualStrings("", (try interfaces.Event.get_type(event)).asSlice());

    var t = try runtime.DOMString.initDupe(allocator, "type");
    defer t.deinit(allocator);
    try interfaces.Event.call_initEvent(event, t, OptBool.notPassed(), OptBool.notPassed());

    // initialize an event, step 1: "Set event's initialized flag."
    try std.testing.expect(initialized(event));
}

test "inner event creation steps initialize an Event subclass's Event attributes through the steps Event installs" {
    const allocator = std.testing.allocator;

    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.createNullContext(allocator);
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    // An interface that inherits from Event, made as its constructor makes
    // it (step 1) - its own state ahead of the Event state it contains.
    const event = try interfaces.CustomEvent.init(allocator, ctx);
    defer interfaces.CustomEvent.deinit(event);
    try std.testing.expect(!initialized(event));

    var caller_owned = try runtime.DOMString.initDupe(allocator, "made");
    try dom.event_construction.innerEventCreationSteps(event, caller_owned, .{ .bubbles = true, .composed = true });
    caller_owned.deinit(allocator);

    // 2. The initialized flag.
    try std.testing.expect(initialized(event));
    // 3. timeStamp: the creation time.
    try std.testing.expect(try interfaces.Event.get_timeStamp(event) > 0);
    // 4. The dictionary's members; a member not present is its default.
    try std.testing.expect(try interfaces.Event.get_bubbles(event));
    try std.testing.expect(!try interfaces.Event.get_cancelable(event));
    try std.testing.expect(try interfaces.Event.get_composed(event));
    // Every other attribute keeps its initial value.
    try std.testing.expect(!try interfaces.Event.get_isTrusted(event));
    try std.testing.expect(try interfaces.Event.get_returnValue(event));
    try std.testing.expect(!try interfaces.Event.get_defaultPrevented(event));
    try std.testing.expectEqual(interfaces.Event.get_NONE(), try interfaces.Event.get_eventPhase(event));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Event.get_target(event));
    // The constructor's step 2: the type, a string the event owns.
    const observed = try interfaces.Event.get_type(event);
    try std.testing.expectEqualStrings("made", observed.asSlice());
}

test "Event's IDL getters read the dispatch state the dispatcher writes" {
    const allocator = std.testing.allocator;

    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.createNullContext(allocator);
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const event = try newEvent(ctx, "x");
    defer interfaces.Event.deinit(event);
    const other = try newEvent(ctx, "y");
    defer interfaces.Event.deinit(other);

    // One state, Event's, which dom.event_dispatch hands the dispatcher
    // (tmp/plans/impls-boundary-design.md 3.4 e2). Its initial values are the
    // attributes' (DOM 2.2): no target, NONE, untrusted.
    const state = dom.event_dispatch.of(event).?;
    try std.testing.expect(state.initialized_flag);
    try std.testing.expectEqual(@as(?*runtime.Instance, null), state.target);
    try std.testing.expectEqual(interfaces.Event.get_NONE(), state.phase);
    try std.testing.expect(!state.is_trusted);

    // What dispatch writes there, the IDL attributes report.
    state.target = other;
    state.current_target = other;
    state.phase = interfaces.Event.get_AT_TARGET();
    state.is_trusted = true;
    try std.testing.expectEqual(@as(?*runtime.Instance, other), try interfaces.Event.get_target(event));
    try std.testing.expectEqual(@as(?*runtime.Instance, other), try interfaces.Event.get_srcElement(event));
    try std.testing.expectEqual(@as(?*runtime.Instance, other), try interfaces.Event.get_currentTarget(event));
    try std.testing.expectEqual(interfaces.Event.get_AT_TARGET(), try interfaces.Event.get_eventPhase(event));
    try std.testing.expect(try interfaces.Event.get_isTrusted(event));

    // And what the IDL operations write, the dispatcher reads.
    try interfaces.Event.call_stopImmediatePropagation(event);
    try std.testing.expect(state.stop_propagation_flag and state.stop_immediate_propagation_flag);
    state.target = null;
}
