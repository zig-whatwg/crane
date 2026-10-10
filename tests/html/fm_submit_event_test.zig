//! A SubmitEvent freed before wrapping releases its own state, not its submitter.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const browser_mod = @import("browser");
const testing = std.testing;

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const button = try interfaces.HTMLButtonElement.init(testing.allocator, realm);
    const generation = runtime.SlabAllocator.generationOf(button);
    const event = try interfaces.SubmitEvent.call_constructor(realm, runtime.DOMString.initInterned("submit"), .passed(.{ .base = .{}, .submitter = button }));
    // traceChild makes the child's wrapper and holds it pending the event's
    // wrapper. The native event itself must still have no wrapper.
    try testing.expect(!engine.hasWrapper(event));
    try testing.expect(engine.hasWrapper(button));
    event.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(event));
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(button));
    try testing.expect(!runtime.instance_lifecycle.isCleanedUp(button));
}

test "unwrapped SubmitEvent teardown releases its state without freeing the supplied submitter" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                std.debug.print("SubmitEvent teardown fixture failed: {s}\n", .{@errorName(err)});
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
