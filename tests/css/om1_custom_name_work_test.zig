//! CSSOM §2.1 / declaration-block serialization step 4.4: identifier spelling
//! must not require a temporary owned string for every custom declaration.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn serializationAllocations(input: []const u8, expected: []const u8, names: []const []const u8) !usize {
    var counted = std.testing.FailingAllocator.init(a, .{});
    const allocator = counted.allocator();
    var allocations: usize = 0;
    {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
        defer block.deinit();
        try std.testing.expectEqual(names.len, block.entries.items.len);
        for (names, 0..) |name, index| try std.testing.expectEqualStrings(name, block.item(index).?);

        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        // Setup and required result capacity are outside the measured operation.
        // Use the same allocator as the block, which appends into this buffer.
        try output.ensureTotalCapacity(allocator, expected.len);
        const before = counted.allocations;
        try block.serialize(&output);
        allocations = counted.allocations - before;
        try std.testing.expectEqualStrings(expected, output.items);
    }
    try std.testing.expectEqual(counted.allocated_bytes, counted.freed_bytes);
    return allocations;
}

test "custom declaration names add no per-name allocation to serialization" {
    var input: std.ArrayList(u8) = .empty;
    defer input.deinit(a);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(a);
    var storage: [32][16]u8 = undefined;
    var names: [32][]const u8 = undefined;
    for (&names, 0..) |*name, index| {
        name.* = try std.fmt.bufPrint(&storage[index], "--om1-c{d}", .{index});
        try input.appendSlice(a, name.*);
        try input.appendSlice(a, ":1px;");
        if (index != 0) try expected.append(a, ' ');
        try expected.appendSlice(a, name.*);
        try expected.appendSlice(a, ": 1px;");
    }
    const allocations = try serializationAllocations(input.items, expected.items, &names);
    // Existing work: one done bitmap and one value buffer per declaration.
    // Report the number of excess allocations on failure, without timing.
    try std.testing.expectEqual(@as(usize, 0), allocations -| (names.len + 1));
}

test "custom declaration allocation accounting preserves escaped spelling and decoded names" {
    const allocations = try serializationAllocations(
        "--x\\ y:1px;--\\ :2px",
        "--x\\ y: 1px; --\\ : 2px;",
        &.{ "--x y", "-- " },
    );
    // Permit the previous owned escaped-name path in this correctness control.
    try std.testing.expectEqual(@as(usize, 0), allocations -| 7);
}

test "identifier serialization preserves bytes for leading digits Unicode and controls" {
    // CSSOM §2.1: pin the existing owned serializer before factoring its core.
    // These same expected bytes must survive the append-based implementation.
    for ([_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "1x", .expected = "\\31 x" },
        .{ .input = "-0a", .expected = "-\\30 a" },
        .{ .input = "-", .expected = "\\-" },
        .{ .input = "--é", .expected = "--é" },
        .{ .input = "--\x01", .expected = "--\\1 " },
    }) |case| {
        const serialized = try css.serialize.serializeIdentifier(a, case.input);
        defer a.free(serialized);
        try std.testing.expectEqualStrings(case.expected, serialized);

        var appended: std.ArrayList(u8) = .empty;
        defer appended.deinit(a);
        const prefix = "prefix: ";
        try appended.appendSlice(a, prefix);
        try css.serialize.appendIdentifier(&appended, a, case.input);
        try std.testing.expectEqualStrings(prefix, appended.items[0..prefix.len]);
        try std.testing.expectEqualStrings(case.expected, appended.items[prefix.len..]);
    }
}
