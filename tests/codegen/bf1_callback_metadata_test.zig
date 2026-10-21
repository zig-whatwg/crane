const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "only annotated nullable callback attributes receive legacy conversion" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/bf1_callback_metadata"}, &cfg);
    const path = try std.fs.path.join(testing.allocator, &.{ root, "interfaces/CallbackAttributes.zig" });
    defer testing.allocator.free(path);
    const output = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "pub const legacy_treat_non_object_as_null = .{\"set_legacy\"};") != null);
}
