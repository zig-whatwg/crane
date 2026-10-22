//! Unforgeability is a member's IDL property, independent of its interface name.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "LegacyUnforgeable metadata identifies attributes and operations" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/bf1_binding_metadata"}, &cfg);
    const path = try std.fs.path.join(testing.allocator, &.{ root, "interfaces/NullableRequired.zig" });
    defer testing.allocator.free(path);
    const output = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "pub const unforgeable_members = .{ \"fixed\", \"fixedOperation\" };") != null);
    const plain_path = try std.fs.path.join(testing.allocator, &.{ root, "interfaces/OptionalConstructor.zig" });
    defer testing.allocator.free(plain_path);
    const plain = try std.Io.Dir.cwd().readFileAlloc(testing.io, plain_path, testing.allocator, .limited(1024 * 1024));
    defer testing.allocator.free(plain);
    try testing.expect(std.mem.indexOf(u8, plain, "unforgeable_members") == null);
}
