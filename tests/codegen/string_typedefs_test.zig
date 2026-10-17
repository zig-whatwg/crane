//! The generated interfaces import DOMString, USVString and ByteString from
//! the typedefs module (writer.zig's getImportModule), so codegen writes
//! their typedef files - re-exports of the runtime string types - whether
//! or not an IDL file declares them. Until webref bfbec43f44 the file
//! existed only because DOM-Style.idl declared `typedef dom::DOMString
//! DOMString`; with that file gone, every interface whose signatures name
//! DOMString stopped compiling.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn readGenerated(root: []const u8, sub_path: []const u8) ![]u8 {
    const path = try std.fs.path.join(testing.allocator, &.{ root, sub_path });
    defer testing.allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1 << 20));
}

test "the string typedef files exist and re-export the runtime string types when no IDL declares them" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/string_typedefs"}, &cfg);

    const typedefs_root = try readGenerated(root, "typedefs/root.zig");
    defer testing.allocator.free(typedefs_root);
    inline for (.{ "DOMString", "USVString", "ByteString" }) |name| {
        const file = try readGenerated(root, "typedefs/" ++ name ++ ".zig");
        defer testing.allocator.free(file);
        try testing.expect(contains(file, "pub const " ++ name ++ " = runtime." ++ name ++ ";"));
        try testing.expect(contains(typedefs_root, "pub const " ++ name ++ " = @import(\"" ++ name ++ ".zig\")." ++ name ++ ";"));
    }
}
