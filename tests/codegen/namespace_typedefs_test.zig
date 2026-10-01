//! Namespace operations are named and bound as an interface's are.
//!
//! A namespace operation's typedefs resolve to the types they name, so
//! CSS.escape(CSSOMString) takes and returns a string, not a raw JSValue.
//! (Namespaces do not import the typedefs module, so a typedef of a simple
//! type is written as that type; a typedef of a union stays a JSValue.)

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "namespace operations write a typedef of a simple type as that type, through typedefs of typedefs" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/namespace_typedefs"}, &cfg);

    for ([_][]const u8{ "namespaces/Space.zig", "impls_tmp/Space.zig" }) |sub_path| {
        const path = try std.fs.path.join(testing.allocator, &.{ root, sub_path });
        defer testing.allocator.free(path);
        const out = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
        defer testing.allocator.free(out);
        testing.expect(contains(out, "call_escape(ctx: runtime.Context, ident: runtime.DOMString) anyerror!runtime.DOMString")) catch |err| {
            std.debug.print("{s}:\n{s}\n", .{ sub_path, out });
            return err;
        };
        try testing.expect(contains(out, "call_check(ctx: runtime.Context, property: runtime.DOMString, value: webidl.Opt(runtime.DOMString)) anyerror!bool"));
        try testing.expect(contains(out, "call_take(ctx: runtime.Context, either: runtime.JSValue)"));
    }
}

fn generateSpace(root: []const u8) !void {
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/namespace_typedefs"}, &cfg);
}

fn readOut(root: []const u8, sub_path: []const u8) ![]u8 {
    const path = try std.fs.path.join(testing.allocator, &.{ root, sub_path });
    defer testing.allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
}

test "an overloaded namespace operation is call_<name> then call_<name>__<k>, never a name mangled with its types" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    try generateSpace(root);

    const ns = try readOut(root, "namespaces/Space.zig");
    defer testing.allocator.free(ns);
    try testing.expect(contains(ns, "pub fn call_supports(ctx: runtime.Context, property: runtime.DOMString, value: runtime.DOMString) anyerror!bool"));
    try testing.expect(contains(ns, "pub fn call_supports__1(ctx: runtime.Context, conditionText: runtime.DOMString) anyerror!bool"));
    // A further overload answers NotImplemented until the impl declares it.
    try testing.expect(contains(ns, "if (comptime @hasDecl(Space_impl, \"call_supports__1\"))"));
    // Bound once, under its own name.
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, ns, ".{ \"supports\", \"call_supports\" }"));
    try testing.expect(!contains(ns, "supports_DOMString") and !contains(ns, "supports_Ident"));
    // The overload resolution table, as an interface's.
    try testing.expect(contains(ns, "pub const overloads = .{"));
    try testing.expect(contains(ns, ".{ .function = \"call_supports\", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.string} } } },"));
    try testing.expect(contains(ns, ".{ .function = \"call_supports__1\", .implemented = @hasDecl(Space_impl, \"call_supports__1\"), .args = &.{.{ .kinds = &.{.string} }} },"));

    const impl = try readOut(root, "impls_tmp/Space.zig");
    defer testing.allocator.free(impl);
    try testing.expect(contains(impl, "pub fn call_supports(ctx: runtime.Context, property: runtime.DOMString, value: runtime.DOMString) anyerror!bool"));
    try testing.expect(contains(impl, "pub fn call_supports__1(ctx: runtime.Context, conditionText: runtime.DOMString) anyerror!bool"));
    try testing.expect(!contains(impl, "supports_DOMString") and !contains(impl, "supports_Ident"));
}
