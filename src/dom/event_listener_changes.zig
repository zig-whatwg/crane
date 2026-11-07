//! A change of an event target's event listener list, told to the target's
//! owner: what an object needs that "MUST NOT be garbage collected if it has
//! an event listener whose type is" some type (Permissions §6.3.5 for
//! PermissionStatus; WebSockets §7, XHR §3.2, HTML §9.2.9 and §9.5 and others
//! have the same shape).
//!
//! WebKit's shape: `EventTarget::eventListenersDidChange()`, a virtual that
//! EventTarget.cpp calls after `addEventListener` adds, after a
//! `removeEventListener` that removed, and after `removeAllEventListeners` -
//! which the event handler setter, the once removal in
//! `innerInvokeEventListeners` and the abort-signal removal all reach - and
//! never from the destructor; `PermissionStatus::eventListenersDidChange`
//! recomputes `hasEventListeners(changeEvent)`, which its
//! `virtualHasPendingActivity` answers. Blink: `EventTarget::AddedEventListener`
//! / `RemovedEventListener`, which `PermissionStatus` overrides, with
//! ActiveScriptWrappable's `HasPendingActivity`.
//!
//! A virtual costs every target a call. Here only a target whose owner asked
//! pays: the owner calls `watch(target)` from its construction steps, which
//! sets a flag in the target's EventTarget state (EventTarget's step, installed
//! with `install`), and EventTarget calls `changed(target)` after its list
//! changed only when that flag is set - every other target pays one byte test.
//! `changed` runs every owner's step (`installStep`, at process start); each
//! step answers only for its own type and reads what it needs
//! (dom.event_listener_types). No step runs script, and none is told of a
//! target's teardown: the list goes with the target.
//!
//! lint-impls: hook for EventTarget, PermissionStatus

const std = @import("std");
const runtime = @import("runtime");
const hook = @import("hook.zig");

/// EventTarget's step: from now on, report every change of `target`'s event
/// listener list (`changed`). Allocates only for a target whose impl never
/// ran EventTarget's construction steps (its state is then made here).
pub const Watch = *const fn (target: *runtime.Instance) error{OutOfMemory}!void;

/// An owner's step: `target`'s event listener list changed - a listener was
/// appended, or one was removed. It returns at once for a target that is not
/// its owner's type, and runs no script.
pub const Step = *const fn (target: *runtime.Instance) void;

/// EventTarget's step. Process-wide, written once at start-up (hook.zig).
var implementation: hook.Hook(?Watch) = .init(null);

/// The owners' steps, few and known at start-up.
const max_steps = 8;
/// Process-wide, written once at start-up (hook.zig).
var steps: hook.Hook(hook.List(Step, max_steps)) = .init(.empty);

/// EventTarget's install, before any Browser exists.
pub fn install(watch_step: Watch) void {
    implementation.install(watch_step);
}

/// An owner's install, before any Browser exists. Idempotent: the same
/// function installs once.
pub fn installStep(step: Step) void {
    const list = steps.installing();
    for (list.slice()) |existing| if (existing == step) return;
    list.append(step);
}

/// The owner, in `target`'s construction steps: report every later change
/// of its event listener list to the installed steps. With no EventTarget
/// installed, no target exists to watch.
pub fn watch(target: *runtime.Instance) error{OutOfMemory}!void {
    const step = implementation.get() orelse return;
    try step(target);
}

/// EventTarget, after `target`'s event listener list changed, for a target
/// some owner watches.
pub fn changed(target: *runtime.Instance) void {
    for (steps.read().slice()) |step| step(target);
}

test "changed runs every installed step once for the target it is given, however often each was installed" {
    const Test = struct {
        var runs: usize = 0;
        var other_runs: usize = 0;
        var last: ?*runtime.Instance = null;
        fn step(target: *runtime.Instance) void {
            runs += 1;
            last = target;
        }
        fn otherStep(_: *runtime.Instance) void {
            other_runs += 1;
        }
    };
    const override = steps.overrideForTest(.empty);
    defer override.restore();

    var target: runtime.Instance = undefined;
    changed(&target);
    try std.testing.expectEqual(@as(usize, 0), Test.runs);

    installStep(&Test.step);
    installStep(&Test.step);
    installStep(&Test.otherStep);
    changed(&target);
    try std.testing.expectEqual(@as(usize, 1), Test.runs);
    try std.testing.expectEqual(@as(usize, 1), Test.other_runs);
    try std.testing.expectEqual(@as(?*runtime.Instance, &target), Test.last);
}

test "watch reaches EventTarget's installed step, and does nothing with none installed" {
    const Test = struct {
        var watched: ?*runtime.Instance = null;
        fn watchStep(target: *runtime.Instance) error{OutOfMemory}!void {
            watched = target;
        }
    };
    var target: runtime.Instance = undefined;
    {
        const override = implementation.overrideForTest(null);
        defer override.restore();
        try watch(&target);
        try std.testing.expectEqual(@as(?*runtime.Instance, null), Test.watched);
    }
    const override = implementation.overrideForTest(&Test.watchStep);
    defer override.restore();
    try watch(&target);
    try std.testing.expectEqual(@as(?*runtime.Instance, &target), Test.watched);
}
