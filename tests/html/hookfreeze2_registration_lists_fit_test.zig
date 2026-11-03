//! The registration lists - `Hook(hook.List(T, capacity))` slots that several
//! owners append to while the process starts (src/process/hook.zig) - hold
//! everything the start installs, with room for one more owner. An append
//! past a list's capacity panics, naming it (a hook dropped silently is a
//! feature lost silently), so a start that reaches its end fits; a list left
//! FULL would make the next owner that registers panic the process start.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const testing = std.testing;

fn checkLists() !void {
    // A Browser starts the whole process: every installHooks, the browser
    // layer's included (crane.Process.ensureStarted).
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();

    const adopting = dom.adopting_steps.installedCount();
    try testing.expect(adopting >= 1);
    try testing.expect(adopting < dom.adopting_steps.max_entries);

    const finishing = dom.finish_parsing_children.installedCount();
    try testing.expect(finishing >= 1);
    try testing.expect(finishing < dom.finish_parsing_children.max_entries);

    const owner_steps = dom.bfcache.installedOwnerSteps();
    inline for (.{ owner_steps.blockers.len, owner_steps.store_steps.len, owner_steps.restore_steps.len }) |count| {
        try testing.expect(count >= 1);
        try testing.expect(count < dom.bfcache.max_owner_steps);
    }
}

test "the process start fits every registration list, with room for one more owner" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            checkLists() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
