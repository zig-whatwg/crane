//! Constructor arity comes from IDL optionality, not the Zig value type.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "constructor minimum arity distinguishes nullable optional variadic and sequence arguments" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/bf1_binding_metadata"}, &cfg);
    for ([_]struct { name: []const u8, count: usize }{
        .{ .name = "NullableRequired", .count = 1 },
        .{ .name = "OptionalConstructor", .count = 0 },
        .{ .name = "VariadicConstructor", .count = 0 },
        .{ .name = "SequenceConstructor", .count = 1 },
        .{ .name = "OverloadedConstructor", .count = 0 },
        .{ .name = "OptionalThenRequired", .count = 2 },
    }) |case| {
        const path = try std.fmt.allocPrint(testing.allocator, "{s}/interfaces/{s}.zig", .{ root, case.name });
        defer testing.allocator.free(path);
        const output = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
        defer testing.allocator.free(output);
        const expected = try std.fmt.allocPrint(testing.allocator, "pub const constructor_required_arguments: usize = {d};", .{case.count});
        defer testing.allocator.free(expected);
        try testing.expect(std.mem.indexOf(u8, output, expected) != null);
    }
}
