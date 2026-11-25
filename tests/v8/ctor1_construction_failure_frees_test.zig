//! A construction that fails after it made its object frees that object WHOLE
//! (lane ctor1; queue item 9 of tmp/plans/queue-0.1-audit.md, found by lane
//! hard1, class B).
//!
//! WebIDL 3.7.1 (the interface object's steps 1.8-1.9) makes the object,
//! then runs the constructor steps with it as "this". When a step fails, the
//! binding never receives the object: the construction is its only owner,
//! and nothing else will ever free it. About 370 impl constructors made the
//! object themselves and, on failure, ran only their own deinit - a
//! destructor, not a free (docs/lessons/architecture-an-interfaces-deinit-
//! is-a-destructor-not-a-free.md) - so the object's slab slot and State
//! stayed until its Browser ended. The bug-finding run reports them at that
//! end as live never-wrapped instances (lane hard1: 6,860 TextDecoders after
//! encoding/).
//!
//! One test per failure family, each red while a family member leaks:
//! - steps that fail after the make (an allocation the steps make, swept
//!   index by index): Event, a subclass of a subclass (KeyboardEvent), and
//!   a constructor that registers itself (BroadcastChannel);
//! - a constructor that made child objects, then failed: MessageChannel
//!   (its ports).
//! Script that throws inside the steps, after the make - TransformStream's
//! transformer.start() - is tests/v8/ctor1_transform_stream_start_test.zig's
//! (its own merge: the stream kept its startPromise).
//!
//! Each failed construction must leave the scope's slab with the objects it
//! had before (`currently_allocated`): the object made, and any child of it,
//! back. The allocation sweeps run in a realm with no engine behind it and a
//! standalone runtime of their own (test_process.OwnRuntime), each failure
//! index on its own thread, as tests/v8/sa_abortcontroller_oom_test.zig's.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const testing = std.testing;

/// The live objects of the standalone runtime's slab: the scope every realm
/// of this file makes its objects in (no Browser owns them).
fn liveObjects() usize {
    const scope = runtime.BrowserScope.standalone() orelse return 0;
    return scope.slab.stats().currently_allocated;
}

/// A construction under test: makes one object in `realm`, or fails.
const Construct = *const fn (realm: runtime.Context) anyerror!*runtime.Instance;

/// One construction with the realm allocator's allocation `fail_after`
/// (counted from the construction's first) refused, or none.
const Trial = struct {
    construct: Construct,
    fail_after: ?usize,
    allocations: usize = 0,
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn check(self: *Trial) !void {
        var failing = testing.FailingAllocator.init(testing.allocator, .{});
        const own_runtime = test_process.OwnRuntime.begin(failing.allocator());
        defer own_runtime.end();
        var context = try runtime.ContextData.init(failing.allocator(), .{});
        defer context.deinit();

        const before = liveObjects();
        const initial = failing.alloc_index;
        if (self.fail_after) |after| failing.fail_index = initial + after;
        const made = self.construct(&context) catch |err| {
            failing.fail_index = std.math.maxInt(usize);
            try testing.expect(self.fail_after != null);
            try testing.expectEqual(error.OutOfMemory, err);
            try testing.expect(failing.has_induced_failure);
            const after = liveObjects();
            if (after != before) {
                std.debug.print("allocation {d} refused: the scope's live objects {d} -> {d}\n", .{ self.fail_after.?, before, after });
                return error.InstanceLeaked;
            }
            return;
        };
        self.allocations = failing.alloc_index - initial;
        failing.fail_index = std.math.maxInt(usize);
        try testing.expect(self.fail_after == null);
        // The construction's owner frees it whole, children included.
        runtime.gc.releaseOwned(made);
        const after = liveObjects();
        if (after != before) {
            std.debug.print("a constructed object freed whole: the scope's live objects {d} -> {d}\n", .{ before, after });
            return error.InstanceLeaked;
        }
    }
};

/// Refuses each allocation of `construct` in turn - every one a failure
/// after the object was made leaves the scope as it found it.
fn sweep(name: []const u8, construct: Construct) !void {
    var success: Trial = .{ .construct = construct, .fail_after = null };
    const warm = try std.Thread.spawn(.{}, Trial.run, .{&success});
    warm.join();
    try success.result;
    try testing.expect(success.allocations > 0);
    for (0..success.allocations) |index| {
        var trial: Trial = .{ .construct = construct, .fail_after = index };
        const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
        thread.join();
        trial.result catch |err| {
            std.debug.print("{s}: allocation failure index {d}/{d}\n", .{ name, index, success.allocations });
            return err;
        };
    }
}

/// A type no event table lists, so that the steps copy it (DOM "initialize
/// event's type attribute": event_construction.ownedType) - an allocation
/// after the make.
const unlisted_type = "ctor1-an-event-type-no-table-lists";

fn newEvent(realm: runtime.Context) anyerror!*runtime.Instance {
    const Args = std.meta.ArgsTuple(@TypeOf(interfaces.Event.call_constructor));
    const Init = @FieldType(Args, "2");
    return interfaces.Event.call_constructor(realm, runtime.DOMString.initInterned(unlisted_type), Init.notPassed());
}

fn newKeyboardEvent(realm: runtime.Context) anyerror!*runtime.Instance {
    const Args = std.meta.ArgsTuple(@TypeOf(interfaces.KeyboardEvent.call_constructor));
    const Init = @FieldType(Args, "2");
    const Dictionary = @FieldType(Init, "value");
    var dictionary: Dictionary = .{ .base = .{ .base = .{ .base = .{} } } };
    dictionary.key = runtime.DOMString.initInterned("ctor1-a-key-name-long-enough-to-be-copied");
    dictionary.code = runtime.DOMString.initInterned("ctor1-a-code-name-long-enough-to-be-copied");
    return interfaces.KeyboardEvent.call_constructor(realm, runtime.DOMString.initInterned(unlisted_type), Init.passed(dictionary));
}

fn newBroadcastChannel(realm: runtime.Context) anyerror!*runtime.Instance {
    return interfaces.BroadcastChannel.call_constructor(realm, runtime.DOMString.initInterned("ctor1-channel"));
}

fn newMessageChannel(realm: runtime.Context) anyerror!*runtime.Instance {
    return interfaces.MessageChannel.call_constructor(realm);
}

test "an Event whose steps fail after it was made frees it whole" {
    try sweep("Event", newEvent);
}

test "a KeyboardEvent whose steps fail after it was made frees it whole" {
    try sweep("KeyboardEvent", newKeyboardEvent);
}

test "a BroadcastChannel whose steps fail after it was made frees it whole" {
    try sweep("BroadcastChannel", newBroadcastChannel);
}

test "a MessageChannel that fails after making its ports frees it and its ports whole" {
    try sweep("MessageChannel", newMessageChannel);
}
