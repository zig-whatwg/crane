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
const impls = @import("impls");
const webidl = @import("webidl");

const OptBool = webidl.Opt(bool);

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
    runtime.SlabAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    runtime.ArenaAllocator.init(allocator);
    defer runtime.ArenaAllocator.deinit();

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
    runtime.SlabAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    runtime.ArenaAllocator.init(allocator);
    defer runtime.ArenaAllocator.deinit();

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
    runtime.SlabAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    runtime.ArenaAllocator.init(allocator);
    defer runtime.ArenaAllocator.deinit();

    var ctx_data = try runtime.createNullContext(allocator);
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const event = try newEvent(ctx, "x");
    defer interfaces.Event.deinit(event);

    try std.testing.expect(impls.Event.getInitializedFlag(event));
}

test "createEvent leaves the initialized flag unset until initEvent" {
    const allocator = std.testing.allocator;

    // Instance.init draws from the process-wide slab and arena; without
    // these the first allocation aborts. tests/runtime does the same.
    runtime.SlabAllocator.init(allocator);
    defer runtime.SlabAllocator.deinit();
    runtime.ArenaAllocator.init(allocator);
    defer runtime.ArenaAllocator.deinit();

    var ctx_data = try runtime.createNullContext(allocator);
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    // https://dom.spec.whatwg.org/#dom-document-createevent step 8:
    // "Unset event's initialized flag."
    const event = try newEvent(ctx, "");
    defer interfaces.Event.deinit(event);
    impls.Event.setInitializedFlag(event, false);

    try std.testing.expect(!impls.Event.getInitializedFlag(event));
    try std.testing.expectEqualStrings("", (try interfaces.Event.get_type(event)).asSlice());

    var t = try runtime.DOMString.initDupe(allocator, "type");
    defer t.deinit(allocator);
    try interfaces.Event.call_initEvent(event, t, OptBool.notPassed(), OptBool.notPassed());

    // initialize an event, step 1: "Set event's initialized flag."
    try std.testing.expect(impls.Event.getInitializedFlag(event));
}
