//! SVG 2's IDL names DOMRect, DOMMatrix and DOMPoint by their legacy window
//! aliases (SVGRect, SVGMatrix, SVGPoint), which WebIDL does not make type
//! names. specs/supplementary/svg-geometry-aliases.idl declares them as
//! typedefs, so the members return the platform object the browsers bind
//! (getBBox() is a DOMRect in all three) rather than an untyped JSValue.
//! A typedef of an interface is that interface's `*runtime.Instance`.

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

test "SVG's SVGRect, SVGMatrix and SVGPoint resolve to the geometry platform objects through the supplementary typedefs" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    // The supplementary source is the committed file itself, alone in a
    // directory of its own, so the test pins what codegen actually reads.
    try tmp.dir.createDirPath(testing.io, "supplementary");
    const idl = try std.Io.Dir.cwd().readFileAlloc(testing.io, "specs/supplementary/svg-geometry-aliases.idl", testing.allocator, .limited(1 << 16));
    defer testing.allocator.free(idl);
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "supplementary/svg-geometry-aliases.idl", .data = idl });
    try tmp.dir.createDirPath(testing.io, "out");
    const supplementary = try tmp.dir.realPathFileAlloc(testing.io, "supplementary", testing.allocator);
    defer testing.allocator.free(supplementary);
    const root = try tmp.dir.realPathFileAlloc(testing.io, "out", testing.allocator);
    defer testing.allocator.free(root);

    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = root };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &.{ "tests/codegen/fixtures/svg_geometry_aliases", supplementary }, &cfg);

    const graphics = try readGenerated(root, "impls_tmp/SVGGraphicsElement.zig");
    defer testing.allocator.free(graphics);
    try testing.expect(contains(graphics, "pub fn call_getBBox(instance: *runtime.Instance) anyerror!typedefs.SVGRect"));
    try testing.expect(contains(graphics, "pub fn call_getCTM(instance: *runtime.Instance) anyerror!?typedefs.SVGMatrix"));

    const svg = try readGenerated(root, "impls_tmp/SVGSVGElement.zig");
    defer testing.allocator.free(svg);
    try testing.expect(contains(svg, "pub fn call_createSVGMatrix(instance: *runtime.Instance) anyerror!typedefs.SVGMatrix"));
    try testing.expect(contains(svg, "pub fn call_createSVGPoint(instance: *runtime.Instance) anyerror!typedefs.SVGPoint"));
    try testing.expect(contains(svg, "pub fn call_createSVGRect(instance: *runtime.Instance) anyerror!typedefs.SVGRect"));
    try testing.expect(!contains(svg, "runtime.JSValue"));

    // Each alias is the interface's platform-object type, as WindowProxy is.
    inline for (.{ "SVGRect", "SVGMatrix", "SVGPoint" }) |name| {
        const typedef = try readGenerated(root, "typedefs/" ++ name ++ ".zig");
        defer testing.allocator.free(typedef);
        try testing.expect(contains(typedef, "pub const " ++ name ++ " = *runtime.Instance;"));
    }
}
