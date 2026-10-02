//! Making a NavigationHistoryEntry for a session history entry, and asking
//! one which entry it stands for: the navigation API's entry list is
//! Navigation's, but what an entry object records is NavigationHistoryEntry's
//! state, so NavigationHistoryEntry installs this hook and Navigation asks it.
//!
//! lint-impls: hook for NavigationHistoryEntry
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

pub const Implementation = struct {
    /// A new NavigationHistoryEntry in `window`'s realm for the session
    /// history entry `entry` (an html_core joint_history.Entry).
    create: *const fn (window: *runtime.Instance, entry: *const anyopaque) anyerror!*runtime.Instance,
    /// The id of the session history entry `instance` stands for.
    entry_id: *const fn (instance: *runtime.Instance) u64,
};

var implementation: ?Implementation = null;

/// Called by NavigationHistoryEntry's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation != null;
}

pub fn create(window: *runtime.Instance, entry: *const anyopaque) !*runtime.Instance {
    const impl = implementation orelse return error.NotSupported;
    return impl.create(window, entry);
}

pub fn entryId(instance: *runtime.Instance) u64 {
    const impl = implementation orelse return 0;
    return impl.entry_id(instance);
}

test "without an installed implementation nothing is made" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    var window: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, create(&window, @ptrCast(&window)));
    try std.testing.expectEqual(@as(u64, 0), entryId(&window));
}
