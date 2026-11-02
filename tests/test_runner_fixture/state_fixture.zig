//! A test executable whose tests each leave one kind of process state behind,
//! built with the Crane test runner (tests/test_runner/) in its failing mode
//! and run - one process per test - by tools/test_launcher/child.zig's tests:
//! the runner's state check must fail each by the name of the field it left
//! changed, and pass the tests that leave nothing or only start the process.
//! Not part of any suite: build.zig compiles it only for the launcher's tests.

const std = @import("std");
const runtime = @import("runtime");
const dom = @import("dom");

test "leaves nothing" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    scope.deinit();
}

test "leaves a Browser alive" {
    // From the page allocator, so that only the state check sees it.
    const scope = try std.heap.page_allocator.create(runtime.BrowserScope);
    scope.* = runtime.BrowserScope.init(std.heap.page_allocator);
}

fn noEntry(_: *runtime.Instance, _: *const anyopaque) anyerror!*runtime.Instance {
    return error.NotSupported;
}

fn noEntryId(_: *runtime.Instance) u64 {
    return 0;
}

const fake_entries: dom.navigation_history_entries.Implementation = .{ .create = noEntry, .entry_id = noEntryId };

test "installs a hook for itself, as startHooksForTest does" {
    // A unit test with no Browser starts the hooks it needs itself: the
    // process start's to make, so not a change it left.
    dom.process_start.installForTest(struct {
        fn installFake() void {
            dom.navigation_history_entries.install(fake_entries);
        }
    }.installFake);
}

test "starts the process, installing a hook" {
    // What a test may do: start the process (tests/v8/test_process.zig's
    // `start`), its hooks with it.
    try std.testing.expect(dom.process_start.begin());
    dom.navigation_history_entries.install(fake_entries);
    dom.process_start.finish(false);
}

test "overrides a hook and gives it back" {
    const override = dom.global_settings.overrideForTest();
    override.restore();
}

test "leaves a hook overridden" {
    // A swap the test never gives back: dom.Hook's override without its
    // restore().
    _ = dom.global_settings.overrideForTest();
}

test "leaves the process starting" {
    try std.testing.expect(dom.process_start.begin());
}

test "ends the process" {
    try std.testing.expect(dom.process_start.begin());
    dom.process_start.finish(false);
    dom.process_start.end();
}

test "leaves the timer nesting level raised" {
    runtime.timer.nesting_level += 1;
}
