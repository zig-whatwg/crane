//! CSSOM §2.1: unchanged identifier bytes need one output growth.
//! Count backing allocations separately from serialization correctness.
const std = @import("std");
const css = @import("css");

test "appendIdentifier - unchanged long name needs only one growth allocation" {
    // Force growth to allocate, independently of backing allocator remap behavior.
    var counted = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .resize_fail_index = 0,
    });
    const allocator = counted.allocator();
    const prefix = "prefix: ";
    const identifier = "--" ++ &@as([510:0]u8, @splat('a'));
    var work: usize = 0;
    {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        try output.ensureTotalCapacityPrecise(allocator, prefix.len);
        try output.appendSlice(allocator, prefix);
        const before = counted.allocations;
        try css.serialize.appendIdentifier(&output, allocator, identifier);
        work = counted.allocations - before;
        try std.testing.expectEqualStrings(prefix, output.items[0..prefix.len]);
        try std.testing.expectEqualStrings(identifier, output.items[prefix.len..]);
    }
    try std.testing.expectEqual(counted.allocated_bytes, counted.freed_bytes);
    try std.testing.expectEqual(counted.allocations, counted.deallocations);
    // Predicted RED on current native Zig 0.16: 3. Single appendSlice: 1.
    try std.testing.expectEqual(@as(usize, 1), work);
}

test "appendIdentifier - Unicode replacement and escapes retain prefix and bytes" {
    const allocator = std.testing.allocator;
    for ([_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "--é\u{1D306}", .expected = "--é\u{1D306}" },
        .{ .input = "--\u{FFFD}", .expected = "--\u{FFFD}" },
        .{ .input = "--\u{0800}", .expected = "--\u{0800}" },
        .{ .input = "--\u{10FFFF}", .expected = "--\u{10FFFF}" },
        .{ .input = "--0", .expected = "--0" },
        .{ .input = "é0", .expected = "é0" },
        .{ .input = "-é0", .expected = "-é0" },
        .{ .input = "", .expected = "" },
        .{ .input = "--@[`{", .expected = "--\\@\\[\\`\\{" },
        .{ .input = "--\x80", .expected = "--\u{FFFD}" },
        .{ .input = "--\xc0\x80", .expected = "--\u{FFFD}\u{FFFD}" },
        .{ .input = "--\xf4\x90\x80\x80", .expected = "--\u{FFFD}\u{FFFD}\u{FFFD}\u{FFFD}" },
        .{ .input = "--\x00\x7f", .expected = "--\u{FFFD}\\7f " },
        .{ .input = "--\xff", .expected = "--\u{FFFD}" },
        .{ .input = "--\xc3", .expected = "--\u{FFFD}" },
        .{ .input = "--\xed\xa0\x80", .expected = "--\u{FFFD}\u{FFFD}\u{FFFD}" },
        .{ .input = "--\xe2(\xa1", .expected = "--\u{FFFD}\\(\u{FFFD}" },
    }) |case| {
        const owned = try css.serialize.serializeIdentifier(allocator, case.input);
        defer allocator.free(owned);
        try std.testing.expectEqualStrings(case.expected, owned);
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        const prefix = "prefix: ";
        try output.appendSlice(allocator, prefix);
        try css.serialize.appendIdentifier(&output, allocator, case.input);
        try std.testing.expectEqualStrings(prefix, output.items[0..prefix.len]);
        try std.testing.expectEqualStrings(case.expected, output.items[prefix.len..]);
    }
}

test "appendIdentifier - first growth OOM preserves prefix and permits cleanup" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = failing.allocator();
    const prefix = "prefix: ";
    const identifier = "--" ++ &@as([510:0]u8, @splat('a'));
    {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        // Setup and cleanup both pass through this same accounting wrapper.
        try output.ensureTotalCapacityPrecise(allocator, prefix.len);
        try output.appendSlice(allocator, prefix);
        try std.testing.expectEqual(prefix.len, output.capacity);
        // Fail both remap and its allocation fallback at the first growth.
        failing.resize_fail_index = failing.resize_index;
        failing.fail_index = failing.alloc_index;
        try std.testing.expectError(error.OutOfMemory, css.serialize.appendIdentifier(&output, allocator, identifier));
        try std.testing.expect(failing.has_induced_failure);
        // No name byte fits before this forced failure. This does not assert
        // equality of partial-name output when a later growth fails.
        try std.testing.expectEqualStrings(prefix, output.items);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    try std.testing.expectEqual(failing.allocations, failing.deallocations);
}
