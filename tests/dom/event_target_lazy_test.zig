//! Manual test to verify EventTarget lazy allocation works

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const EventTarget = dom.EventTarget;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("Testing EventTarget lazy allocation...\n", .{});

    // Test 1: EventTarget starts with null list
    {
        var target = try EventTarget.init(allocator);
        defer target.deinit();

        const is_null = target.event_listener_list == null;
        std.debug.print("Test 1 - Starts null: {}\n", .{is_null});
        if (!is_null) return error.TestFailed;
    }

    // Test 2: addEventListener allocates list
    {
        var target = try EventTarget.init(allocator);
        defer target.deinit();

        try target.call_addEventListener("click", .{ .js_value = 42 }, .{});

        const is_allocated = target.event_listener_list != null;
        std.debug.print("Test 2 - Allocated after addEventListener: {}\n", .{is_allocated});
        if (!is_allocated) return error.TestFailed;

        const count = target.event_listener_list.?.items.len;
        std.debug.print("Test 2 - Listener count: {}\n", .{count});
        if (count != 1) return error.TestFailed;
    }

    // Test 3: Memory savings simulation
    {
        const num_targets = 100;
        var targets: [num_targets]EventTarget = undefined;

        // Init all
        for (&targets) |*t| {
            t.* = try EventTarget.init(allocator);
        }
        defer {
            for (&targets) |*t| {
                t.deinit();
            }
        }

        // Only 10% get listeners
        for (targets[0..10]) |*t| {
            try t.call_addEventListener("click", .{ .js_value = 1 }, .{});
        }

        // Count allocations
        var allocated: usize = 0;
        for (targets) |*t| {
            if (t.event_listener_list != null) {
                allocated += 1;
            }
        }

        std.debug.print("Test 3 - Created {} EventTargets\n", .{num_targets});
        std.debug.print("Test 3 - Only {} allocated lists ({d:.1}%)\n", .{ allocated, @as(f64, @floatFromInt(allocated)) / @as(f64, @floatFromInt(num_targets)) * 100.0 });
        std.debug.print("Test 3 - Memory saved on {} targets ({d:.1}%)\n", .{ num_targets - allocated, @as(f64, @floatFromInt(num_targets - allocated)) / @as(f64, @floatFromInt(num_targets)) * 100.0 });

        if (allocated != 10) return error.TestFailed;
    }

    std.debug.print("\nAll tests passed! ✓\n", .{});
    std.debug.print("Lazy allocation saves memory on ~90% of EventTargets.\n", .{});
}
