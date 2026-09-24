//! DOM § 4.4 "cloning steps", as the hook other specifications reach.
//!
//! "Clone a node" step 3: "Run any cloning steps defined for node in other
//! applicable specifications and pass node, copy, and subtree as
//! parameters." HTML defines them for `script` (copy "already started"),
//! `input` (value, dirtiness and checkedness) and `template` (the contents).
//!
//! The clone algorithm is Node's, and a base type cannot depend on its
//! subtypes, so each owning impl installs its steps here when its first
//! element is created - necessarily before there is one to clone - and the
//! algorithm runs every installed set. The same shape as `mutation.zig`'s
//! insertion-steps registry.
//!
//! lint-impls: hook for HTMLScriptElement

const std = @import("std");
const runtime = @import("runtime");

/// One specification's cloning steps. They run for every clone, so each set
/// returns at once for a node it does not own. `copy` implements the same
/// interfaces as `node` ("clone a single node" step 3).
pub const Steps = *const fn (node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) anyerror!void;

/// One slot per owning interface; installed for the life of the process.
var installed: [8]Steps = undefined;
var installed_count: usize = 0;

/// Called by an owning impl. Idempotent: a set already installed is not
/// installed twice.
pub fn install(steps: Steps) void {
    for (installed[0..installed_count]) |existing| {
        if (existing == steps) return;
    }
    std.debug.assert(installed_count < installed.len);
    installed[installed_count] = steps;
    installed_count += 1;
}

/// "Clone a node" step 3.
pub fn run(node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) !void {
    for (installed[0..installed_count]) |steps| try steps(node, copy, subtree);
}

test "every installed set runs once per clone, in installation order" {
    const saved_count = installed_count;
    const saved = installed;
    defer {
        installed = saved;
        installed_count = saved_count;
    }
    installed_count = 0;

    const Record = struct {
        var calls: [4]u8 = undefined;
        var len: usize = 0;
        var last_subtree: bool = false;
        fn first(_: *runtime.Instance, _: *runtime.Instance, subtree: bool) anyerror!void {
            calls[len] = 1;
            len += 1;
            last_subtree = subtree;
        }
        fn second(_: *runtime.Instance, _: *runtime.Instance, _: bool) anyerror!void {
            calls[len] = 2;
            len += 1;
        }
    };
    install(&Record.first);
    install(&Record.second);
    install(&Record.first);
    try std.testing.expectEqual(@as(usize, 2), installed_count);

    // Never dereferenced: the recorded steps ignore both instances.
    var node: runtime.Instance = undefined;
    var copy: runtime.Instance = undefined;
    try run(&node, &copy, true);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, Record.calls[0..Record.len]);
    try std.testing.expect(Record.last_subtree);
}

test "a failing set stops the clone" {
    const saved_count = installed_count;
    const saved = installed;
    defer {
        installed = saved;
        installed_count = saved_count;
    }
    installed_count = 0;
    install(&struct {
        fn fail(_: *runtime.Instance, _: *runtime.Instance, _: bool) anyerror!void {
            return error.OutOfMemory;
        }
    }.fail);
    var node: runtime.Instance = undefined;
    var copy: runtime.Instance = undefined;
    try std.testing.expectError(error.OutOfMemory, run(&node, &copy, false));
}
