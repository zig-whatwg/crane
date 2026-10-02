//! HTML 6.4.1 "Tracking user activation", the data model: each Window has a
//! last activation timestamp and a last history-action activation timestamp.
//!
//! They are the Window's own state, and no IDL member sets them - the
//! activation notification, activation consumption and history-action
//! consumption do (src/html/user_activation.zig). So Window installs this
//! hook from its installHooks, and the algorithms reach the timestamps through it,
//! without importing Window.
//!
//! A timestamp is milliseconds on the process's shared monotonic clock
//! (HR-Time's "unsafe shared current time", before coarsening), so one
//! Window's timestamp compares with another's; positive infinity means never
//! activated and negative infinity means consumed, as in the spec.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#user-activation-data-model
//!
//! lint-impls: hook for Window

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const clock = @import("clock");

/// The clock every timestamp here is on: milliseconds of the process's
/// shared monotonic clock (HR-Time "unsafe shared current time"), with
/// nanosecond resolution.
pub fn sharedCurrentTime() f64 {
    return @as(f64, @floatFromInt(clock.monotonicNanos())) / std.time.ns_per_ms;
}

/// A Window's two user activation timestamps. The defaults are the spec's
/// initial values: positive infinity, never activated.
pub const Timestamps = struct {
    last_activation: f64 = std.math.inf(f64),
    last_history_action_activation: f64 = std.math.inf(f64),
};

/// What Window supplies.
pub const Implementation = struct {
    /// `window`'s timestamps, or null when `window` is not a Window.
    get: *const fn (window: *runtime.Instance) ?Timestamps,
    /// Set `window`'s timestamps; nothing when it is not a Window.
    set: *const fn (window: *runtime.Instance, timestamps: Timestamps) void,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by Window's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `window`'s timestamps. Before any Window exists there is no Window to
/// have been activated: the initial values.
pub fn get(window: *runtime.Instance) Timestamps {
    const impl = implementation orelse return .{};
    return impl.get(window) orelse .{};
}

/// Set `window`'s timestamps.
pub fn set(window: *runtime.Instance, timestamps: Timestamps) void {
    const impl = implementation orelse return;
    impl.set(window, timestamps);
}

test "without an installed implementation every window reads as never activated" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads the window.
    var window: runtime.Instance = undefined;
    const timestamps = get(&window);
    try std.testing.expect(std.math.isPositiveInf(timestamps.last_activation));
    try std.testing.expect(std.math.isPositiveInf(timestamps.last_history_action_activation));
    set(&window, .{ .last_activation = 1 });
}

test "get and set forward to the installed implementation" {
    const saved = implementation;
    defer implementation = saved;
    const Fake = struct {
        var stored: Timestamps = .{};
        fn get(_: *runtime.Instance) ?Timestamps {
            return stored;
        }
        fn set(_: *runtime.Instance, timestamps: Timestamps) void {
            stored = timestamps;
        }
    };
    install(.{ .get = &Fake.get, .set = &Fake.set });
    var window: runtime.Instance = undefined;
    set(&window, .{ .last_activation = 5, .last_history_action_activation = 3 });
    try std.testing.expectEqual(@as(f64, 5), get(&window).last_activation);
    try std.testing.expectEqual(@as(f64, 3), get(&window).last_history_action_activation);
}
