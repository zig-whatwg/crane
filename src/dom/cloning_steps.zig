//! DOM § 4.4 "cloning steps", as the hook other specifications reach.
//!
//! "Clone a node" step 3: "Run any cloning steps defined for node in other
//! applicable specifications and pass node, copy, and subtree as
//! parameters." HTML defines them for `script` (copy "already started"),
//! `input` (value, dirtiness, checkedness and indeterminateness), `textarea`
//! (raw value and dirtiness) and `template` (the contents).
//!
//! The clone algorithm is Node's, and a base type cannot depend on its
//! subtypes, so each owning impl installs its steps here once, at process
//! start (its installHooks), and the algorithm runs every installed set. The same shape as `mutation.zig`'s
//! insertion-steps registry.
//!
//! lint-impls: hook for HTMLScriptElement, SVGScriptElement, HTMLTemplateElement, Document, HTMLInputElement, HTMLTextAreaElement, HTMLElement, SVGElement

const std = @import("std");
const hook = @import("hook.zig");
const runtime = @import("runtime");

/// One specification's cloning steps. They run for every clone, so each set
/// returns at once for a node it does not own. `copy` implements the same
/// interfaces as `node` ("clone a single node" step 3).
pub const Steps = *const fn (node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) anyerror!void;

/// One slot per owning interface; installed for the life of the process.
/// Eight owners install today (Document, Input, TextArea, Script, Template,
/// SVGScript, HTMLElement, SVGElement); room for more (row 46 review S1).
var installed: hook.Hook(hook.List(Steps, 16)) = .init(.empty);

/// Called by an owning's installHooks, once, at process start (process_start.zig).
pub fn install(steps: Steps) void {
    const list = installed.installing();
    if (list.contains(steps)) return;
    list.append(steps);
}

/// "Clone a node" step 3.
pub fn run(node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) !void {
    for (installed.read().slice()) |steps| try steps(node, copy, subtree);
}

test "every installed set runs once per clone, in installation order" {
    const override = installed.overrideForTest(.empty);
    defer override.restore();

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
    try std.testing.expectEqual(@as(usize, 2), installed.get().len);

    // Never dereferenced: the recorded steps ignore both instances.
    var node: runtime.Instance = undefined;
    var copy: runtime.Instance = undefined;
    try run(&node, &copy, true);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, Record.calls[0..Record.len]);
    try std.testing.expect(Record.last_subtree);
}

test "a failing set stops the clone" {
    const override = installed.overrideForTest(.empty);
    defer override.restore();
    install(&struct {
        fn fail(_: *runtime.Instance, _: *runtime.Instance, _: bool) anyerror!void {
            return error.OutOfMemory;
        }
    }.fail);
    var node: runtime.Instance = undefined;
    var copy: runtime.Instance = undefined;
    try std.testing.expectError(error.OutOfMemory, run(&node, &copy, false));
}
