//! A Browser's profile directory is its alone while it lives (docs/instances.md
//! "One live Browser per profile directory"; lane life1, the user's ruling D6
//! 2026-11-21: Puppeteer's --user-data-dir fully supported): a second live
//! Browser given the same directory fails to start with error.ProfileInUse,
//! as Chrome's profile lock refuses one, and once the first ends the
//! directory is free again. A Browser with no profile directory writes
//! nothing to disk.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

fn profileIsHeldWhileItsBrowserLives() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const profile = try std.fs.path.join(testing.allocator, &.{ base, "profile" });
    defer testing.allocator.free(profile);

    const first = try Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = profile });
    // The directory was made, with its lock file.
    try tmp.dir.access(testing.io, "profile/LOCK", .{});
    // A second live Browser on it is refused, and leaves nothing behind.
    try testing.expectError(error.ProfileInUse, Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = profile }));
    first.deinit();
    // Free again once the first has ended.
    const third = try Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = profile });
    third.deinit();
}

test "a second live Browser on the same profile directory fails with ProfileInUse, and the directory is free once the first ends" {
    // Its own thread: each Browser's window agent, as the directory's other
    // tests do (AGENTS.md "A test directory is one executable").
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            profileIsHeldWhileItsBrowserLives() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn twoProfilesTwoBrowsers() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const one = try std.fs.path.join(testing.allocator, &.{ base, "one" });
    defer testing.allocator.free(one);
    const two = try std.fs.path.join(testing.allocator, &.{ base, "two" });
    defer testing.allocator.free(two);
    // Different directories are different profiles: both live at once.
    const a = try Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = one });
    defer a.deinit();
    const b = try Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = two });
    defer b.deinit();
}

test "Browsers on two profile directories live at once" {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            twoProfilesTwoBrowsers() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
