//! Resource Timing's secondary-buffer transfer preserves FIFO order and
//! reserves a large destination once. Allocation failure keeps the old
//! per-entry behavior, including the prefix that already fits.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const timing = @import("dom").performance_timeline;

test "copy secondary buffer reserves once for a large ordered transfer" {
    const allocator = std.testing.allocator;
    const entries = try allocator.alloc(runtime.Instance, 1000);
    defer allocator.free(entries);
    // A successful transfer only moves pointers: the owner's existing
    // edges stay in place and no instance is accessed.
    var owner: runtime.Instance = undefined;
    var measured = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
    var timeline = timing.Timeline.init(measured.allocator(), &owner);
    defer timeline.deinit();
    for (entries) |*entry| try timeline.resource.secondary_buffer.append(measured.allocator(), entry);
    timing.setResourceTimingBufferSize(&timeline, 700);
    const before = measured.alloc_index;
    timing.copySecondaryBuffer(&timeline);
    try std.testing.expectEqual(@as(usize, 1), measured.alloc_index - before);
    try std.testing.expectEqual(@as(usize, 700), timeline.resource.current_size);
    const primary = &timeline.buffers.getPtr(.resource).entries;
    try std.testing.expectEqual(@as(usize, 700), primary.items.len);
    try std.testing.expectEqual(@as(usize, 300), timeline.resource.secondary_buffer.items.len);
    for (primary.items, entries[0..700]) |entry, *expected| try std.testing.expectEqual(expected, entry);
    for (timeline.resource.secondary_buffer.items, entries[700..]) |entry, *expected| try std.testing.expectEqual(expected, entry);
    // Reducing the limit below the current size neither evicts entries
    // nor underflows the available-space calculation.
    timing.setResourceTimingBufferSize(&timeline, 200);
    timing.copySecondaryBuffer(&timeline);
    try std.testing.expectEqual(@as(usize, 700), timeline.resource.current_size);
    try std.testing.expectEqual(@as(usize, 300), timeline.resource.secondary_buffer.items.len);
    try std.testing.expectEqual(@as(usize, 1), measured.alloc_index - before);
    timing.setResourceTimingBufferSize(&timeline, 1000);
    timing.copySecondaryBuffer(&timeline);
    try std.testing.expectEqual(@as(usize, 1000), primary.items.len);
    try std.testing.expectEqual(@as(usize, 1000), timeline.resource.current_size);
    try std.testing.expectEqual(@as(usize, 0), timeline.resource.secondary_buffer.items.len);
    for (primary.items, entries) |entry, *expected| try std.testing.expectEqual(expected, entry);
}

test "secondary-buffer allocation failure keeps the prefix that fits and empties the secondary buffer" {
    const Trial = struct {
        fn run(result: *anyerror!void) void {
            result.* = check();
        }

        fn check() !void {
            const allocator = std.testing.allocator;
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            var realm = try runtime.ContextData.init(allocator, .{});
            defer realm.deinit();
            const owner = try interfaces.Performance.init(allocator, &realm);
            defer runtime.Instance.deinit(owner);
            const entries = try allocator.alloc(runtime.Instance, 1000);
            defer allocator.free(entries);
            var failing = std.testing.FailingAllocator.init(allocator, .{});
            var timeline = timing.Timeline.init(failing.allocator(), owner);
            defer timeline.deinit();
            const primary = &timeline.buffers.getPtr(.resource).entries;
            try primary.ensureTotalCapacityPrecise(failing.allocator(), 10);
            for (entries) |*entry| try timeline.resource.secondary_buffer.append(failing.allocator(), entry);
            const fits = primary.capacity;
            timing.setResourceTimingBufferSize(&timeline, 1000);
            failing.fail_index = failing.alloc_index;
            failing.resize_fail_index = failing.resize_index;
            timing.copySecondaryBuffer(&timeline);
            try std.testing.expect(failing.has_induced_failure);
            try std.testing.expectEqual(fits, primary.items.len);
            try std.testing.expectEqual(fits, timeline.resource.current_size);
            try std.testing.expectEqual(@as(usize, 0), timeline.resource.secondary_buffer.items.len);
            for (primary.items, entries[0..fits]) |entry, *expected| try std.testing.expectEqual(expected, entry);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&result});
    thread.join();
    try result;
}
