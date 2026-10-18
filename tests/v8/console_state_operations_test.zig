//! Console 1.2/1.4: generated namespace calls retain valid, owned state.
const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const console = @import("v8").namespace_mod.generated_namespaces.console;
const testing = std.testing;

test "console.countReset removes the counter as Chrome and Firefox do" {
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const label = webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned("iw1-counter"));

    try console.call_count(&ctx, label);
    try console.call_count(&ctx, label);
    try testing.expectEqual(@as(?u32, 2), ctx.console_state.count_map.get("iw1-counter"));
    try console.call_countReset(&ctx, label);
    try testing.expectEqual(@as(?u32, null), ctx.console_state.count_map.get("iw1-counter"));
    try console.call_countReset(&ctx, label);
    // The missing entry takes the existing warning branch on the second reset.
    try testing.expectEqual(@as(?u32, null), ctx.console_state.count_map.get("iw1-counter"));
    try console.call_count(&ctx, label);
    try testing.expectEqual(@as(?u32, 1), ctx.console_state.count_map.get("iw1-counter"));
}

test "console.count never retains a borrowed label when allocation fails" {
    for (0..4) |fail_index| {
        try allocationFailure(.count, fail_index, false);
        try allocationFailure(.count, fail_index, true);
    }
}

test "console.time never retains a borrowed label when allocation fails" {
    for (0..4) |fail_index| {
        try allocationFailure(.time, fail_index, false);
        try allocationFailure(.time, fail_index, true);
    }
}

const Operation = enum { count, time };

fn allocationFailure(comptime operation: Operation, fail_index: usize, seeded: bool) !void {
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const map = if (operation == .count) &ctx.console_state.count_map else &ctx.console_state.timer_table;
    if (seeded) {
        const seed = try testing.allocator.dupe(u8, "unrelated-counter-or-timer");
        errdefer testing.allocator.free(seed);
        try map.put(seed, 17);
    }
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = fail_index });
    ctx.allocator = failing.allocator();
    defer ctx.allocator = testing.allocator;
    map.allocator = failing.allocator();

    var label_bytes = "iw1-borrowed-label".*;
    const label = webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(&label_bytes));
    if (operation == .count) try console.call_count(&ctx, label) else try console.call_time(&ctx, label);

    if (seeded) try testing.expectEqual(17, map.get("unrelated-counter-or-timer").?);
    if (failing.has_induced_failure) {
        // Remove a bad entry before asserting, so the red test reports the
        // ownership failure instead of freeing a stack pointer at teardown.
        const retained_entry = map.contains(&label_bytes);
        if (map.getEntry(&label_bytes)) |entry| {
            if (entry.key_ptr.*.ptr == label_bytes[0..].ptr) _ = map.remove(&label_bytes);
        }
        try testing.expect(!retained_entry);
    } else {
        const entry = map.getEntry(&label_bytes).?;
        try testing.expect(entry.key_ptr.*.ptr != label_bytes[0..].ptr);
        if (operation == .count) try testing.expectEqual(@as(u32, 1), entry.value_ptr.*);

        // Existing entries need no label allocation, even under memory pressure.
        failing.fail_index = failing.alloc_index;
        if (operation == .count) {
            try console.call_count(&ctx, label);
            try testing.expectEqual(@as(?u32, 2), map.get(&label_bytes));
        } else {
            const start = entry.value_ptr.*;
            try console.call_time(&ctx, label);
            try testing.expectEqual(@as(?i64, start), map.get(&label_bytes));
        }
        try testing.expect(!failing.has_induced_failure);
    }
}
