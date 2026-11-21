//! An element's own step for an event at its place on the event's path,
//! before that item's listeners run: Blink's Node::HandleLocalEvents
//! (WebKit's handleLocalEvents, Gecko's WillHandleEvent), which an element
//! type overrides. No spec has such a step; each one installed here says
//! which browser behaviour it follows and why golden rule 2 takes it.
//!
//! The type that owns a step installs it at process start for the event
//! types it is for, and EventTarget's dispatch asks once per dispatch whether
//! the event's type has one (`forType`): with none installed for the type,
//! that is the whole cost. Only then does "invoke" run the step for each item
//! of the path, and a `stop` sets the event's stop propagation flag and runs
//! none of that item's listeners.
//!
//! lint-impls: hook for HTMLFormElement

const std = @import("std");
const hook = @import("hook.zig");
const runtime = @import("runtime");
const listener_list = @import("event_listener_list.zig");

/// What a step decides for one item of the path.
pub const Verdict = enum {
    /// Run the item's listeners, as with no step.
    proceed,
    /// Stop the event here: set its stop propagation flag and run none of
    /// this item's listeners.
    stop,
};

/// A step: given the path item's invocation target `node`, the event's
/// target at that item ("invoke" steps 1-3), and the event phase
/// (dom.event_dispatch.Phase), whether the event goes on.
pub const Run = *const fn (node: *runtime.Instance, target: *runtime.Instance, phase: u8) Verdict;

/// One owner's step for one event type.
pub const Step = struct {
    /// The event type the step is for.
    event_type: []const u8,
    run: Run,
};

/// An installed step, with its type looked up once.
const Entry = struct {
    key: listener_list.Key,
    run: Run,
};

const max_steps = 8;
/// Process-wide, written once at start-up (hook.zig).
var steps: hook.Hook(hook.List(Entry, max_steps)) = .init(.empty);

/// Install `step`. Idempotent: the same step for the same type is kept once.
pub fn install(step: Step) void {
    const entry: Entry = .{ .key = listener_list.Key.of(step.event_type), .run = step.run };
    const installed = steps.installing();
    for (installed.slice()) |e| {
        if (e.run == entry.run and sameType(e.key, entry.key)) return;
    }
    installed.append(entry);
}

/// The step for events of `key`'s type, or null: asked once per dispatch.
pub inline fn forType(key: listener_list.Key) ?Run {
    const installed = steps.read().slice();
    if (installed.len == 0) return null;
    for (installed) |entry| {
        if (sameType(entry.key, key)) return entry.run;
    }
    return null;
}

fn sameType(a: listener_list.Key, b: listener_list.Key) bool {
    // A listed type is its id; an unlisted one is its bytes, and a listed
    // type never equals an unlisted one.
    if (a.static_bits != 0 or b.static_bits != 0) return a.static_bits == b.static_bits;
    return std.mem.eql(u8, a.bytes, b.bytes);
}

test "a step is found for its type only, and installed once" {
    const S = struct {
        fn stop(_: *runtime.Instance, _: *runtime.Instance, _: u8) Verdict {
            return .stop;
        }
    };
    const override = steps.overrideForTest(.empty);
    defer override.restore();
    try std.testing.expect(forType(listener_list.Key.of("submit")) == null);
    const installed = steps.installing();
    installed.append(.{ .key = listener_list.Key.of("submit"), .run = &S.stop });
    try std.testing.expect(forType(listener_list.Key.of("submit")).? == &S.stop);
    try std.testing.expect(forType(listener_list.Key.of("reset")) == null);
    try std.testing.expect(forType(listener_list.Key.of("submitx")) == null);
}
