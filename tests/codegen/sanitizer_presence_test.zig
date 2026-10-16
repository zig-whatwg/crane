//! Nullable non-null defaults require absence to remain distinct from null.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "dictionary presence rule preserves only nullable non-null defaults and the existing registry exception" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var config = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer config.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/sanitizer_presence"}, &config);
    const expected = .{
        .{ "PresenceRule", "const webidl = @import(\"webidl\");" },
        .{ "PresenceRule", "withDefault: webidl.Opt(?runtime.DOMString) = .notPassed()," },
        .{ "PresenceRule", "withoutDefault: ?runtime.DOMString = null," },
        .{ "PresenceRule", "nullDefault: ?runtime.DOMString = null," },
        .{ "PresenceRule", "nonnullableDefault: ?runtime.DOMString = null," },
        .{ "PresenceRule", "requiredNullable: runtime.DOMString," },
        .{ "ShadowRootInit", "customElementRegistry: webidl.Opt(?runtime.JSValue) = .notPassed()," },
    };
    inline for (expected) |entry| {
        const path = try std.fs.path.join(testing.allocator, &.{ root, "dictionaries/" ++ entry[0] ++ ".zig" });
        defer testing.allocator.free(path);
        const output = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(65536));
        defer testing.allocator.free(output);
        try testing.expect(std.mem.indexOf(u8, output, entry[1]) != null);
    }
    const path = try std.fs.path.join(testing.allocator, &.{ root, "dictionaries/NoPresence.zig" });
    defer testing.allocator.free(path);
    const output = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(65536));
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "const webidl") == null);
    try testing.expect(std.mem.indexOf(u8, output, "webidl.Opt") == null);
}
