//! A namespace's regular attributes are bound (WebIDL 3.13.1: accessor
//! properties of the namespace object, each a getter - a namespace attribute
//! is readonly). Codegen writes each one's getter, `get_<name>(ctx)`, which
//! runs the impl's getter steps with the current realm and answers
//! NotImplemented until the impl declares them, and lists every attribute in
//! `Meta.attributes` with whether the impl implements it, so the binding
//! installs only those. Before this, an attribute was written as
//! `pub const <name>: T = undefined` and nothing bound it: CSS.paintWorklet
//! was undefined.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "a namespace attribute is a getter delegate with the current realm, listed in Meta.attributes" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{"tests/codegen/fixtures/namespace_attributes"}, &cfg);

    const path = try std.fs.path.join(testing.allocator, &.{ root, "namespaces/Orbit.zig" });
    defer testing.allocator.free(path);
    const out = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
    defer testing.allocator.free(out);

    const expected = [_][]const u8{
        "pub const attributes = .{",
        ".{ \"moon\", \"get_moon\", @hasDecl(Orbit_impl, \"get_moon\") },",
        ".{ \"name\", \"get_name\", @hasDecl(Orbit_impl, \"get_name\") },",
        "pub fn get_moon(ctx: runtime.Context) anyerror!runtime.JSValue {",
        "if (comptime @hasDecl(Orbit_impl, \"get_moon\")) {",
        "return try Orbit_impl.get_moon(ctx);",
        "return error.NotImplemented;",
        "pub fn get_name(ctx: runtime.Context) anyerror!runtime.DOMString {",
    };
    for (expected) |needle| {
        testing.expect(contains(out, needle)) catch |err| {
            std.debug.print("missing: {s}\n{s}\n", .{ needle, out });
            return err;
        };
    }
    // The old placeholder, which nothing bound, is gone.
    try testing.expect(!contains(out, "pub const moon:"));
    try testing.expect(!contains(out, "= undefined;"));
    // Operations are unchanged.
    try testing.expect(contains(out, "pub fn call_spin(ctx: runtime.Context, axis: runtime.DOMString) anyerror!bool"));
}
