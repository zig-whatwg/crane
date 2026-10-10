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

// HTMLOptionsCollection's shape: an inherited `item` getter beside its own
// length attribute and its own anonymous indexed setter. The getter is still
// re-exported (the binding installs indexed access only through a call_item
// it can see), the own length is not shadowed by the parent's, and the setter
// stays the interface's own delegate. A by-name exclusion once kept
// HTMLOptionsCollection from getting call_item, so select.options[i] was unbound.
test "CE2 codegen: an own indexed setter keeps the inherited indexed getter" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer config.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/ce2_collection"}, &config);
    const file = try std.fmt.allocPrint(testing.allocator, "{s}/interfaces/SetterCollection.zig", .{root});
    defer testing.allocator.free(file);
    const output = try std.Io.Dir.cwd().readFileAlloc(testing.io, file, testing.allocator, .limited(65536));
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "pub const call_item = BaseCollection.call_item;") != null);
    try testing.expect(std.mem.indexOf(u8, output, "pub const get_length = BaseCollection.get_length;") == null);
    try testing.expect(std.mem.indexOf(u8, output, "pub fn call_setter(") != null);
}
