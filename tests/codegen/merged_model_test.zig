//! One codegen model over every IDL source.
//!
//! Crane's generated WebIDL tree comes from two directories: specs/idl (the
//! pinned webref snapshot) and specs/supplementary (Crane's own definitions).
//! A definition in one may name a type from the other - specs/supplementary's
//! `typedef Window WindowProxy;` names an interface from specs/idl - so names
//! must resolve against ONE model built from both, and every root.zig must
//! list both sources' entries.
//!
//! Run per source, the second run resolved against its own files only: it
//! wrote WindowProxy as `runtime.JSValue` (it could not see that Window is an
//! interface) and rewrote every root.zig with only its own entries.
//! See docs/lessons/codegen-regenerating-supplementary-alone-rewrites-a-typedef-of-an-idl-interface.md.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

const fixture_idl = "tests/codegen/fixtures/two_sources/idl";
const fixture_supplementary = "tests/codegen/fixtures/two_sources/supplementary";

fn readGenerated(allocator: std.mem.Allocator, root: []const u8, sub_path: []const u8) ![]u8 {
    const path = try std.fs.path.join(allocator, &.{ root, sub_path });
    defer allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, allocator, .limited(1024 * 1024));
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// The number of `pub const X = @import(...)` entries in a generated root.zig.
fn rootEntries(content: []const u8) usize {
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "pub const ") and contains(line, "@import(")) count += 1;
    }
    return count;
}

const Generated = struct {
    tmp: testing.TmpDir,
    root: [:0]u8,

    fn deinit(self: *Generated) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn read(self: *const Generated, sub_path: []const u8) ![]u8 {
        return readGenerated(testing.allocator, self.root, sub_path);
    }
};

fn freshDest() !Generated {
    var tmp = testing.tmpDir(.{});
    errdefer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    return .{ .tmp = tmp, .root = root };
}

fn generate(dest: []const u8, sources: []const []const u8) !void {
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = dest };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, sources, &cfg);
}

test "a run over the supplementary source alone resolves WindowProxy against itself (why one model is needed)" {
    var out = try freshDest();
    defer out.deinit();
    try generate(out.root, &.{fixture_supplementary});

    const window_proxy = try out.read("typedefs/WindowProxy.zig");
    defer testing.allocator.free(window_proxy);
    // Window is not in this run's model, so the typedef's target is unknown.
    try testing.expect(contains(window_proxy, "pub const WindowProxy = runtime.JSValue;"));

    const typedefs_root = try out.read("typedefs/root.zig");
    defer testing.allocator.free(typedefs_root);
    try testing.expect(!contains(typedefs_root, "Label"));
    try testing.expectEqual(@as(usize, 1), rootEntries(typedefs_root));
}

test "one invocation over both sources resolves WindowProxy as Window's instance" {
    var out = try freshDest();
    defer out.deinit();
    try generate(out.root, &.{ fixture_idl, fixture_supplementary });

    const window_proxy = try out.read("typedefs/WindowProxy.zig");
    defer testing.allocator.free(window_proxy);
    try testing.expect(contains(window_proxy, "pub const WindowProxy = *runtime.Instance;"));
}

test "one invocation over both sources lists both sources' entries in every root" {
    var out = try freshDest();
    defer out.deinit();
    try generate(out.root, &.{ fixture_idl, fixture_supplementary });

    const typedefs_root = try out.read("typedefs/root.zig");
    defer testing.allocator.free(typedefs_root);
    try testing.expect(contains(typedefs_root, "pub const Label = "));
    try testing.expect(contains(typedefs_root, "pub const WindowProxy = "));
    try testing.expectEqual(@as(usize, 2), rootEntries(typedefs_root));

    const dictionaries_root = try out.read("dictionaries/root.zig");
    defer testing.allocator.free(dictionaries_root);
    try testing.expect(contains(dictionaries_root, "pub const Options = "));
    try testing.expect(contains(dictionaries_root, "pub const ExtraOptions = "));
    try testing.expectEqual(@as(usize, 2), rootEntries(dictionaries_root));

    const interfaces_root = try out.read("interfaces/root.zig");
    defer testing.allocator.free(interfaces_root);
    try testing.expectEqual(@as(usize, 1), rootEntries(interfaces_root));
}

test "the order of the sources does not change the output" {
    var forward = try freshDest();
    defer forward.deinit();
    try generate(forward.root, &.{ fixture_idl, fixture_supplementary });

    var backward = try freshDest();
    defer backward.deinit();
    try generate(backward.root, &.{ fixture_supplementary, fixture_idl });

    for ([_][]const u8{ "typedefs/WindowProxy.zig", "typedefs/root.zig", "dictionaries/root.zig", "interfaces/Window.zig" }) |sub_path| {
        const a = try forward.read(sub_path);
        defer testing.allocator.free(a);
        const b = try backward.read(sub_path);
        defer testing.allocator.free(b);
        try testing.expectEqualStrings(a, b);
    }
}

// The real inputs: the pinned webref snapshot and Crane's supplementary IDL,
// regenerated from scratch in one invocation, must give every committed
// root.zig its committed entry count, and must carry every supplementary
// definition - an IDL update cannot drop one, because the default sources
// read specs/supplementary in every invocation.

const generated_dirs = [_][]const u8{ "interfaces", "typedefs", "dictionaries", "callbacks", "mixins", "namespaces", "enums" };

test "the default sources are the webref snapshot and the supplementary IDL" {
    try testing.expectEqual(@as(usize, 2), codegen.cli.default_sources.len);
    try testing.expectEqualStrings("specs/idl", codegen.cli.default_sources[0]);
    try testing.expectEqualStrings("specs/supplementary", codegen.cli.default_sources[1]);
}

test "a from-scratch run over the default sources matches every committed root's entry count and keeps the supplementary definitions" {
    var out = try freshDest();
    defer out.deinit();
    try generate(out.root, &codegen.cli.default_sources);

    for (generated_dirs) |dir| {
        const sub_path = try std.fs.path.join(testing.allocator, &.{ dir, "root.zig" });
        defer testing.allocator.free(sub_path);
        const generated = try out.read(sub_path);
        defer testing.allocator.free(generated);
        const committed = try readGenerated(testing.allocator, "src/webidl", sub_path);
        defer testing.allocator.free(committed);
        testing.expectEqual(rootEntries(committed), rootEntries(generated)) catch |err| {
            std.debug.print("{s}: committed {d} entries, regenerated {d}\n", .{ sub_path, rootEntries(committed), rootEntries(generated) });
            return err;
        };
    }

    const window_proxy = try out.read("typedefs/WindowProxy.zig");
    defer testing.allocator.free(window_proxy);
    try testing.expect(contains(window_proxy, "pub const WindowProxy = *runtime.Instance;"));

    // One definition from each specs/supplementary file.
    const typedefs_root = try out.read("typedefs/root.zig");
    defer testing.allocator.free(typedefs_root);
    try testing.expect(contains(typedefs_root, "pub const CSSOMString = "));
    try testing.expect(contains(typedefs_root, "pub const WindowProxy = "));
    const dictionaries_root = try out.read("dictionaries/root.zig");
    defer testing.allocator.free(dictionaries_root);
    try testing.expect(contains(dictionaries_root, "pub const PostMessageOptions = "));
    try testing.expect(contains(dictionaries_root, "pub const XRFeatureInit = "));
    const interfaces_root = try out.read("interfaces/root.zig");
    defer testing.allocator.free(interfaces_root);
    try testing.expect(contains(interfaces_root, "pub const ShadowRealmGlobalScope = "));
    const font_face_set = try out.read("interfaces/FontFaceSet.zig");
    defer testing.allocator.free(font_face_set);
    try testing.expect(contains(font_face_set, "get_size"));
    const window = try out.read("interfaces/Window.zig");
    defer testing.allocator.free(window);
    try testing.expect(contains(window, "call_item"));

    // The buffer source typedefs are written too (they re-export
    // webidl/types/buffer_sources.zig), so every file a root imports exists.
    for ([_][]const u8{ "ArrayBufferView", "BufferSource", "AllowSharedBufferSource" }) |name| {
        const sub_path = try std.fmt.allocPrint(testing.allocator, "typedefs/{s}.zig", .{name});
        defer testing.allocator.free(sub_path);
        const typedef = try out.read(sub_path);
        defer testing.allocator.free(typedef);
        const expected = try std.fmt.allocPrint(testing.allocator, "pub const {s} = webidl.buffer_sources.{s};", .{ name, name });
        defer testing.allocator.free(expected);
        try testing.expect(contains(typedef, expected));
    }
}

/// What `zig fmt` would make of `source`.
fn zigFmt(allocator: std.mem.Allocator, source: []const u8) ![]u8 {
    const source_z = try allocator.dupeZ(u8, source);
    defer allocator.free(source_z);
    var tree = try std.zig.Ast.parse(allocator, source_z, .zig);
    defer tree.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), tree.errors.len);
    return tree.renderAlloc(allocator);
}

test "codegen writes zig fmt-clean files, so a regeneration diffs cleanly against the formatted tree" {
    var out = try freshDest();
    defer out.deinit();
    try generate(out.root, &.{ fixture_idl, fixture_supplementary });

    for ([_][]const u8{ "interfaces/Window.zig", "interfaces/root.zig", "typedefs/WindowProxy.zig", "typedefs/root.zig", "dictionaries/ExtraOptions.zig", "dictionaries/root.zig", "impls_tmp/Window.zig" }) |sub_path| {
        const written = try out.read(sub_path);
        defer testing.allocator.free(written);
        const formatted = try zigFmt(testing.allocator, written);
        defer testing.allocator.free(formatted);
        testing.expectEqualStrings(formatted, written) catch |err| {
            std.debug.print("{s} is not zig fmt-clean\n", .{sub_path});
            return err;
        };
    }
}
