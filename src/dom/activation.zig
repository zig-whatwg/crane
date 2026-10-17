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
//! lint-impls: hook for HTMLAnchorElement, HTMLAreaElement, HTMLButtonElement, HTMLDetailsElement, HTMLInputElement, HTMLLabelElement, SVGAElement

const std = @import("std");
const process_start = @import("process_start.zig");
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
var behaviors: [max_behaviors]Behavior = undefined;
var count: usize = 0;

/// Install `behavior`. Idempotent: installing the same behaviour again adds
/// nothing - and a behaviour is the same only if EVERY function it names is
/// the installed one's. `of` answers with the first behaviour whose check
/// accepts the target.
///
/// Not keyed by `has`: a release build folds functions with identical code
/// into one (LLVM), so two owners' checks that are distinct in Debug can share
/// an address there, and replacing the entry with the same `has` made the
/// LAST behaviour win in release builds and the first in Debug. Folding can
/// make two checks equal but never two whole behaviours that differ, so this
/// table holds what a Debug build's holds, less exact duplicates
/// (docs/lessons/debugging-equal-constants-share-one-address-in-a-release-build.md).
pub fn install(behavior: Behavior) void {
    process_start.assertInstalling();
    for (behaviors[0..count]) |existing| {
        if (std.meta.eql(existing, behavior)) return;
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

test "behaviours that share a check stay two, and the first installed answers: a release build can make two checks one function" {
    // Two owners whose `has` functions have the same body are ONE function in
    // a release build. The table and the answer must be Debug's: both
    // behaviours, the first one installed first.
    const saved_behaviors = behaviors;
    const saved_count = count;
    const saved_runs = test_runs;
    defer {
        behaviors = saved_behaviors;
        count = saved_count;
        test_runs = saved_runs;
    }
    const Later = struct {
        fn run(_: *runtime.Instance, _: *runtime.Instance) void {
            test_runs += 10;
        }
    };
    count = 0;
    test_runs = 0;
    var target: runtime.Instance = undefined;
    install(.{ .has = &testHas, .run = &testRun });
    install(.{ .has = &testHas, .run = &Later.run });
    const behavior = of(&target) orelse return error.TestExpectedBehavior;
    behavior.run(&target, &target);
    try std.testing.expectEqual(@as(usize, 1), test_runs);
}
