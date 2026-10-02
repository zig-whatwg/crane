//! The process's start-up, as src/dom's hook modules see it.
//!
//! docs/instances.md: a hook - a function table the owning impl installs so
//! that code which may not name the impl can reach a step - is the same for
//! every instance and never changes. So it is process-wide and written once,
//! by `crane.Process` (src/browser/process.zig) while the process starts and
//! before any Browser exists: never lazily by its first owner (a lazily
//! installed hook made a page's result depend on which pages ran before it -
//! docs/lessons/architecture-a-threadlocal-hook-installed-by-the-first-owner.md),
//! and never per thread (a threadlocal installed on one thread is null on the
//! next - docs/lessons/architecture-a-threadlocal-is-per-thread-not-per-instance-or-tab.md).
//!
//! Every hook module's install asserts `assertInstalling()`: written while the
//! process starts, read without a lock after, because nothing writes it again.
//! Tests that swap a hook may write it any time (`builtin.is_test`): the Zig
//! test runner runs one test at a time.
//!
//! Blink's CoreInitializer is the same shape: "Initialize must be called once
//! by singleton ModulesInitializer", installing function pointers into core
//! before any frame exists (third_party/blink/renderer/core/core_initializer.h).

const std = @import("std");
const builtin = @import("builtin");

pub const Phase = enum(u8) {
    /// Nothing has started the process.
    not_started,
    /// `crane.Process` is starting it: the engine, then every hook.
    starting,
    /// Started; hooks are read-only from here on.
    running,
    /// `crane.Process.deinit` ran. The engine cannot start again (V8 cannot
    /// initialize its platform twice).
    ended,
};

/// What `crane.Process` records about its start, in one word.
pub const State = packed struct(u16) {
    phase: Phase = .not_started,
    /// The engine was started with a snapshot that agents can be made from.
    has_snapshot: bool = false,
    _unused: u7 = 0,
};

// process-wide: crane.Process's start-up phase; src/dom hooks are written only while it is .starting
var state: std.atomic.Value(State) = .init(.{});

/// The current start-up state.
pub fn get() State {
    return state.load(.acquire);
}

/// Claim the start: not_started -> starting. False when another caller has
/// claimed it (or it has run); that caller finishes it.
pub fn begin() bool {
    return state.cmpxchgStrong(.{}, .{ .phase = .starting }, .acq_rel, .acquire) == null;
}

/// starting -> running: every hook is installed.
pub fn finish(has_snapshot: bool) void {
    std.debug.assert(get().phase == .starting);
    state.store(.{ .phase = .running, .has_snapshot = has_snapshot }, .release);
}

/// running -> ended.
pub fn end() void {
    state.store(.{ .phase = .ended }, .release);
}

/// Wait until a start another caller claimed has finished (or ended).
pub fn waitUntilStarted() Phase {
    while (true) {
        const phase = get().phase;
        if (phase != .starting) return phase;
        std.Thread.yield() catch std.atomic.spinLoopHint();
    }
}

/// Every hook module's install asserts this: hooks are written while the
/// process starts and never after. A lazy install left anywhere - an impl's
/// `init`, a consumer making a throwaway owner - fails here, at its first
/// run, instead of making results depend on what ran before.
pub fn assertInstalling() void {
    if (builtin.is_test) return;
    if (get().phase != .starting) {
        @panic("a src/dom hook was installed outside process start-up: hooks are installed once, by crane.Process (docs/instances.md)");
    }
}

test "the state is one word and starts not started" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(State));
    const initial: State = .{};
    try std.testing.expectEqual(Phase.not_started, initial.phase);
    try std.testing.expect(!initial.has_snapshot);
}
