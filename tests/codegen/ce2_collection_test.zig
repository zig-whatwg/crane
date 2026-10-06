//! Inherited indexed getters still describe the derived legacy platform object.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "CE2 codegen: inherited indexed members reach the parent interface" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer config.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/ce2_collection"}, &config);
    for ([_][]const u8{ "ChildCollection", "OverrideCollection" }) |name| {
        const file = try std.fmt.allocPrint(testing.allocator, "{s}/interfaces/{s}.zig", .{ root, name });
        defer testing.allocator.free(file);
        const output = try std.Io.Dir.cwd().readFileAlloc(testing.io, file, testing.allocator, .limited(65536));
        defer testing.allocator.free(output);
        const inherits = std.mem.eql(u8, name, "ChildCollection");
        try testing.expectEqual(inherits, std.mem.indexOf(u8, output, "pub const call_item = BaseCollection.call_item;") != null);
        try testing.expectEqual(inherits, std.mem.indexOf(u8, output, "pub const get_length = BaseCollection.get_length;") != null);
    }
}
