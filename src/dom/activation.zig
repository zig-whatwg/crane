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
const hook = @import("hook.zig");
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
/// Process-wide, written once at start-up (hook.zig).
var behaviors: hook.Hook(hook.List(Behavior, max_behaviors)) = .init(.empty);

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
    const installed = behaviors.installing();
    if (installed.contains(behavior)) return;
    installed.append(behavior);
}

/// The activation behaviour `target` has, or null.
pub fn of(target: *runtime.Instance) ?Behavior {
    for (behaviors.read().slice()) |behavior| {
        if (behavior.has(target)) return behavior;
    }
    return null;
}

test "a target has the behaviour whose brand check accepts it, installed once" {
    // The test's behaviour: its count lives in the test, not in the product.
    const Test = struct {
        var runs: usize = 0;
        fn has(_: *runtime.Instance) bool {
            return true;
        }
        fn run(_: *runtime.Instance, _: *runtime.Instance) void {
            runs += 1;
        }
    };
    // The test's own empty table, given back whole at its end: this test's
    // always-true brand check must not stay for the process's later tests.
    const override = behaviors.overrideForTest(.empty);
    defer override.restore();
    // Never dereferenced: nothing installed reads the target.
    var target: runtime.Instance = undefined;
    try std.testing.expect(of(&target) == null);
    install(.{ .has = &Test.has, .run = &Test.run });
    install(.{ .has = &Test.has, .run = &Test.run });
    try std.testing.expectEqual(@as(usize, 1), behaviors.get().len);
    const behavior = of(&target) orelse return error.TestExpectedBehavior;
    behavior.run(&target, &target);
    try std.testing.expectEqual(@as(usize, 1), Test.runs);
}

test "behaviours that share a check stay two, and the first installed answers: a release build can make two checks one function" {
    // Two owners whose `has` functions have the same body are ONE function in
    // a release build. The table and the answer must be Debug's: both
    // behaviours, the first one installed first.
    const override = behaviors.overrideForTest(.empty);
    defer override.restore();
    const Test = struct {
        var runs: usize = 0;
        fn has(_: *runtime.Instance) bool {
            return true;
        }
        fn run(_: *runtime.Instance, _: *runtime.Instance) void {
            runs += 1;
        }
        fn later(_: *runtime.Instance, _: *runtime.Instance) void {
            runs += 10;
        }
    };
    var target: runtime.Instance = undefined;
    install(.{ .has = &Test.has, .run = &Test.run });
    install(.{ .has = &Test.has, .run = &Test.later });
    const behavior = of(&target) orelse return error.TestExpectedBehavior;
    behavior.run(&target, &target);
    try std.testing.expectEqual(@as(usize, 1), Test.runs);
}
