//! Allocation failure at any raw-handler store must leave its target destructible.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn store(allocator: std.mem.Allocator, ctx: runtime.Context) !void {
    const target = try interfaces.EventTarget.init(allocator, ctx);
    defer interfaces.EventTarget.deinit(target);
    try dom.event_handlers.setRaw(target, "click", .{ .body = "return 1", .url = "https://handler.test/first" });
    try dom.event_handlers.setRaw(target, "click", .{ .body = "return 2", .url = "https://handler.test/second" });
    try dom.event_handlers.set(?*const fn () void, target, "click", null);
    try dom.event_handlers.setRaw(target, "resize", .{ .body = "return 3", .url = "https://handler.test/third" });
    dom.event_handlers.eraseAll(target);
    try dom.event_handlers.setRaw(target, "click", .{ .body = "return 4", .url = "https://handler.test/teardown" });
}

fn check() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.createNullContext(std.testing.allocator);
    defer ctx.deinit();
    try std.testing.checkAllAllocationFailures(std.testing.allocator, store, .{&ctx});

    // Leave this target to the standalone scope's registry teardown, which
    // releases native source with no engine. The scope owns its slab/state.
    const orphan = try interfaces.EventTarget.init(std.testing.allocator, &ctx);
    try dom.event_handlers.setRaw(orphan, "click", .{ .body = "return 5", .url = "https://handler.test/no-engine" });
}

test "raw handler store releases body and location on every allocation failure" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            check() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
