//! DOM "activation behavior" (DOM 2.9): what an element does when a click
//! event dispatched through it is not cancelled - an `a` follows its
//! hyperlink, a checkbox toggles. Each element type's behaviour reads and
//! writes that type's state, so the type's impl installs it here, and
//! EventTarget's dispatch asks, without importing any element.
//!
//! An owner installs one `Behavior` with a brand check (`is`), since dispatch
//! holds only an EventTarget. Behaviours that need the legacy hooks - a
//! checkbox's legacy-pre-activation and legacy-canceled-activation - supply
//! them; the rest leave them null.
//!
//! Spec: https://dom.spec.whatwg.org/#eventtarget-activation-behavior
//!
//! lint-impls: hook for HTMLAnchorElement, HTMLAreaElement

const std = @import("std");
const runtime = @import("runtime");

/// One element type's activation behaviour.
pub const Behavior = struct {
    /// Whether `target` is of this type AND has activation behaviour now.
    has: *const fn (target: *runtime.Instance) bool,
    /// The activation behaviour, given the event.
    run: *const fn (target: *runtime.Instance, event: *runtime.Instance) void,
    /// Legacy-pre-activation behaviour, run before the event's listeners.
    legacy_pre_activation: ?*const fn (target: *runtime.Instance) void = null,
    /// Legacy-canceled-activation behaviour, run when the event was cancelled.
    legacy_canceled_activation: ?*const fn (target: *runtime.Instance) void = null,
};

const max_behaviors = 16;
threadlocal var behaviors: [max_behaviors]Behavior = undefined;
threadlocal var count: usize = 0;

/// Install `behavior`. Idempotent: the same `has` function installs once.
pub fn install(behavior: Behavior) void {
    for (behaviors[0..count]) |*existing| {
        if (existing.has == behavior.has) {
            existing.* = behavior;
            return;
        }
    }
    if (count == max_behaviors) return;
    behaviors[count] = behavior;
    count += 1;
}

/// The activation behaviour `target` has, or null.
pub fn of(target: *runtime.Instance) ?Behavior {
    for (behaviors[0..count]) |behavior| {
        if (behavior.has(target)) return behavior;
    }
    return null;
}

var test_runs: usize = 0;
fn testHas(_: *runtime.Instance) bool {
    return true;
}
fn testRun(_: *runtime.Instance, _: *runtime.Instance) void {
    test_runs += 1;
}

test "a target has the behaviour whose brand check accepts it, installed once" {
    const saved = count;
    defer count = saved;
    count = 0;
    // Never dereferenced: nothing installed reads the target.
    var target: runtime.Instance = undefined;
    try std.testing.expect(of(&target) == null);
    install(.{ .has = &testHas, .run = &testRun });
    install(.{ .has = &testHas, .run = &testRun });
    try std.testing.expectEqual(@as(usize, 1), count);
    const behavior = of(&target) orelse return error.TestExpectedBehavior;
    behavior.run(&target, &target);
    try std.testing.expectEqual(@as(usize, 1), test_runs);
}
