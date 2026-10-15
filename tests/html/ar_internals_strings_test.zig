//! ARIA defaults own their strings independently of setter and getter buffers.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

fn exercise() !void {
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    const internals = try interfaces.ElementInternals.init(std.testing.allocator, &context);
    defer runtime.Instance.deinit(internals);
    try std.testing.expectEqual(@as(?runtime.DOMString, null), try interfaces.ElementInternals.get_role(internals));
    var input = try runtime.DOMString.initDupe(std.testing.allocator, "Button MiXeD");
    defer input.deinit(std.testing.allocator);
    try interfaces.ElementInternals.set_role(internals, input);
    input.owned[0] = 'X';
    var first = (try interfaces.ElementInternals.get_role(internals)) orelse return error.MissingAriaRole;
    defer first.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("Button MiXeD", first.asSlice());
    first.owned[0] = 'Y';
    var second = (try interfaces.ElementInternals.get_role(internals)) orelse return error.MissingAriaRole;
    defer second.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("Button MiXeD", second.asSlice());
    // Replacing the source does not invalidate either previously returned string.
    try interfaces.ElementInternals.set_role(internals, runtime.DOMString.initEmpty());
    var empty = (try interfaces.ElementInternals.get_role(internals)) orelse return error.MissingEmptyRole;
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("", empty.asSlice());
    try interfaces.ElementInternals.set_role(internals, null);
    try std.testing.expectEqual(@as(?runtime.DOMString, null), try interfaces.ElementInternals.get_role(internals));
    try interfaces.ElementInternals.set_ariaLabel(internals, runtime.DOMString.initInterned("retained through teardown"));
}

test "ARIA internals copy inputs and outputs, preserve empty versus null and release stored strings" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

fn allocationFailure() !void {
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const internals = try interfaces.ElementInternals.init(failing.allocator(), &context);
    defer runtime.Instance.deinit(internals);
    try interfaces.ElementInternals.set_role(internals, runtime.DOMString.initInterned("old"));
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, interfaces.ElementInternals.set_role(internals, runtime.DOMString.initInterned("new value")));
    var value = (try interfaces.ElementInternals.get_role(internals)).?;
    defer value.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("old", value.asSlice());
    // Clearing never allocates, even when every following allocation fails.
    try interfaces.ElementInternals.set_role(internals, null);
    try std.testing.expectEqual(@as(?runtime.DOMString, null), try interfaces.ElementInternals.get_role(internals));
}

test "ARIA internals allocation failure preserves the prior value and null clears without allocation" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            allocationFailure() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
