//! DOM attachShadow must distinguish an absent registry from an explicit null.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "CE2 codegen: ShadowRootInit preserves nullable registry presence" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer config.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/ce2_presence"}, &config);
    const path = try std.fs.path.join(testing.allocator, &.{ root, "dictionaries/ShadowRootInit.zig" });
    defer testing.allocator.free(path);
    const output = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(65536));
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "customElementRegistry: webidl.Opt(?*runtime.Instance)") != null);
}
