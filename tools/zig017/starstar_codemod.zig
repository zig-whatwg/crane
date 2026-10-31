//! The Zig 0.17 `**` codemod (roadmap zig-017; lanes zig017trial and zigprep1).
//!
//! Zig 0.17 removes array multiplication, `a ** n` ("use @splat"). Each form below means the same
//! on Zig 0.16 and 0.17, so the rewrite lands before the port:
//!
//!   [_]T{v} ** n        -> @as([n]T, @splat(v))          ([_:s]T keeps its sentinel)
//!   .{v} ** n           -> @splat(v)                      (the result type comes from the site)
//!   "c" ** n            -> &@as([n:0]u8, @splat('c'))     (a one-byte string literal)
//!
//! Every other `**` (several elements, a longer string, a value that is not a literal, one `**`
//! inside another) is listed MANUAL for a hand rewrite. A rewrite whose result type the site does
//! not supply (`.{v} ** n` with no result type) fails to compile rather than change meaning.
//!
//!     zig build starstar-codemod -- [--dry-run] <file.zig>...
//!
//! Prints one line per site, REWRITE or MANUAL, and a TOTAL; without --dry-run it rewrites each
//! file in place. Run `zig fmt` on the files afterwards.
const std = @import("std");
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;

pub const Site = struct {
    line: usize,
    /// The `a ** n` text.
    before: []const u8,
    /// Its rewrite, or null for a hand rewrite.
    after: ?[]const u8,
};

pub const Result = struct {
    /// The rewritten source (the input itself when nothing was rewritten).
    text: []const u8,
    sites: []const Site,

    pub fn count(result: Result, rewritten: bool) usize {
        var n: usize = 0;
        for (result.sites) |site| {
            if ((site.after != null) == rewritten) n += 1;
        }
        return n;
    }
};

fn nodeSpan(tree: *const Ast, node: Ast.Node.Index) [2]usize {
    const first = tree.firstToken(node);
    const last = tree.lastToken(node);
    return .{ tree.tokenStart(first), tree.tokenStart(last) + tree.tokenSlice(last).len };
}

fn nodeText(tree: *const Ast, node: Ast.Node.Index) []const u8 {
    const s = nodeSpan(tree, node);
    return tree.source[s[0]..s[1]];
}

fn charLiteral(arena: Allocator, byte: u8) ![]const u8 {
    if (byte >= 0x20 and byte < 0x7f and byte != '\'' and byte != '\\') return std.fmt.allocPrint(arena, "'{c}'", .{byte});
    return std.fmt.allocPrint(arena, "0x{x:0>2}", .{byte});
}

/// The rewrite of one `lhs ** rhs`, or null when @splat does not cover it.
fn rewrite(arena: Allocator, tree: *const Ast, lhs: Ast.Node.Index, rhs: Ast.Node.Index) !?[]const u8 {
    const n = nodeText(tree, rhs);
    switch (tree.nodeTag(lhs)) {
        .array_init_one, .array_init_one_comma => {
            var buf: [2]Ast.Node.Index = undefined;
            const init = tree.fullArrayInit(&buf, lhs) orelse return null;
            if (init.ast.elements.len != 1) return null;
            const type_node = init.ast.type_expr.unwrap() orelse return null;
            const arr = tree.fullArrayType(type_node) orelse return null;
            if (!std.mem.eql(u8, nodeText(tree, arr.ast.elem_count), "_")) return null;
            const elem = nodeText(tree, arr.ast.elem_type);
            const v = nodeText(tree, init.ast.elements[0]);
            if (arr.ast.sentinel.unwrap()) |s| {
                return try std.fmt.allocPrint(arena, "@as([{s}:{s}]{s}, @splat({s}))", .{ n, nodeText(tree, s), elem, v });
            }
            return try std.fmt.allocPrint(arena, "@as([{s}]{s}, @splat({s}))", .{ n, elem, v });
        },
        .array_init_dot_two, .array_init_dot_two_comma => {
            var buf: [2]Ast.Node.Index = undefined;
            const init = tree.fullArrayInit(&buf, lhs) orelse return null;
            if (init.ast.elements.len != 1) return null;
            return try std.fmt.allocPrint(arena, "@splat({s})", .{nodeText(tree, init.ast.elements[0])});
        },
        .string_literal => {
            const bytes = std.zig.string_literal.parseAlloc(arena, tree.tokenSlice(tree.nodeMainToken(lhs))) catch return null;
            if (bytes.len != 1) return null;
            return try std.fmt.allocPrint(arena, "&@as([{s}:0]u8, @splat({s}))", .{ n, try charLiteral(arena, bytes[0]) });
        },
        else => return null,
    }
}

const Edit = struct { start: usize, end: usize, text: []const u8 };

/// Every `**` of `source`, rewritten where a form above covers it.
pub fn rewriteSource(arena: Allocator, source: [:0]const u8) !Result {
    var tree = try Ast.parse(arena, source, .{ .mode = .zig });
    if (tree.errors.len != 0) return error.ParseError;
    var mults: std.ArrayList(Ast.Node.Index) = .empty;
    for (0..tree.nodes.len) |i| {
        const node: Ast.Node.Index = @fromBackingInt(@intCast(i));
        if (tree.nodeTag(node) == .array_mult) try mults.append(arena, node);
    }
    var sites: std.ArrayList(Site) = .empty;
    var edits: std.ArrayList(Edit) = .empty;
    for (mults.items) |node| {
        const span = nodeSpan(&tree, node);
        // A `**` inside another `**` is left for the hand rewrite (its text would go stale).
        const nested = for (mults.items) |other| {
            if (other == node) continue;
            const o = nodeSpan(&tree, other);
            if ((o[0] >= span[0] and o[1] <= span[1]) or (span[0] >= o[0] and span[1] <= o[1])) break true;
        } else false;
        const lhs, const rhs = tree.nodeData(node).node_and_node;
        const after = if (nested) null else try rewrite(arena, &tree, lhs, rhs);
        try sites.append(arena, .{
            .line = std.mem.count(u8, source[0..span[0]], "\n") + 1,
            .before = source[span[0]..span[1]],
            .after = after,
        });
        if (after) |text| try edits.append(arena, .{ .start = span[0], .end = span[1], .text = text });
    }
    std.mem.sort(Site, sites.items, {}, struct {
        fn lt(_: void, a: Site, b: Site) bool {
            return a.line < b.line;
        }
    }.lt);
    if (edits.items.len == 0) return .{ .text = source, .sites = sites.items };
    std.mem.sort(Edit, edits.items, {}, struct {
        fn lt(_: void, a: Edit, b: Edit) bool {
            return a.start < b.start;
        }
    }.lt);
    var text: std.ArrayList(u8) = .empty;
    var at: usize = 0;
    for (edits.items) |e| {
        try text.appendSlice(arena, source[at..e.start]);
        try text.appendSlice(arena, e.text);
        at = e.end;
    }
    try text.appendSlice(arena, source[at..]);
    return .{ .text = text.items, .sites = sites.items };
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;
    var args = try init.minimal.args.iterateAllocator(arena);
    _ = args.next();
    var dry_run = false;
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};
    var rewritten: usize = 0;
    var manual: usize = 0;
    while (args.next()) |path| {
        if (std.mem.eql(u8, path, "--dry-run")) {
            dry_run = true;
            continue;
        }
        const source = try std.Io.Dir.cwd().readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        const result = rewriteSource(arena, source) catch |err| switch (err) {
            error.ParseError => {
                try out.print("PARSE-ERROR {s}\n", .{path});
                continue;
            },
            else => return err,
        };
        for (result.sites) |site| {
            if (site.after) |after| {
                try out.print("REWRITE {s}:{d}: {s} -> {s}\n", .{ path, site.line, site.before, after });
            } else {
                try out.print("MANUAL {s}:{d}: {s}\n", .{ path, site.line, site.before });
            }
        }
        rewritten += result.count(true);
        manual += result.count(false);
        if (dry_run or result.count(true) == 0) continue;
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = result.text });
    }
    try out.print("TOTAL rewritten={d} manual={d}\n", .{ rewritten, manual });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn expectRewrite(comptime source: [:0]const u8, comptime expected: []const u8, rewritten: usize, manual: usize) !void {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const result = try rewriteSource(arena_state.allocator(), source);
    try testing.expectEqualStrings(expected, result.text);
    try testing.expectEqual(rewritten, result.count(true));
    try testing.expectEqual(manual, result.count(false));
}

test "a typed one-element array becomes @as of a @splat, keeping its sentinel" {
    try expectRewrite("const a = [_]u8{0} ** 16;\n", "const a = @as([16]u8, @splat(0));\n", 1, 0);
    try expectRewrite("const a = [_:0]u8{' '} ** n;\n", "const a = @as([n:0]u8, @splat(' '));\n", 1, 0);
    try expectRewrite("const a = [_]?*T{null} ** (max - 1);\n", "const a = @as([(max - 1)]?*T, @splat(null));\n", 1, 0);
}

test "an anonymous one-element list becomes a bare @splat" {
    try expectRewrite("var a: [4]u32 = .{7} ** 4;\n", "var a: [4]u32 = @splat(7);\n", 1, 0);
    try expectRewrite("const s: S = .{ .xs = .{.{}} ** 3 };\n", "const s: S = .{ .xs = @splat(.{}) };\n", 1, 0);
}

test "a one-byte string becomes the address of a sentinel-terminated @splat" {
    try expectRewrite("const s = \"x\" ** 3;\n", "const s = &@as([3:0]u8, @splat('x'));\n", 1, 0);
    try expectRewrite("const s = \"\\n\" ** 2;\n", "const s = &@as([2:0]u8, @splat(0x0a));\n", 1, 0);
    try expectRewrite("const s = \"'\" ** 2;\n", "const s = &@as([2:0]u8, @splat(0x27));\n", 1, 0);
}

test "the forms @splat does not cover are left for a hand rewrite" {
    const several = "const a = [_]u8{ 1, 2 } ** 3;\nconst b = \"ab\" ** 2;\nconst c = x ** 2;\n";
    try expectRewrite(several, several, 0, 3);
    // A `**` inside another is never rewritten: the outer text would go stale.
    const nested = "const a = [_][2]u8{[_]u8{0} ** 2} ** 3;\n";
    try expectRewrite(nested, nested, 0, 2);
    // A sized array type is not `[_]`: its count is the type's, not the site's.
    const sized = "const a = [1]u8{0} ** 4;\n";
    try expectRewrite(sized, sized, 0, 1);
}

test "only the `**` changes; the rest of the line, and other lines, stay" {
    try expectRewrite(
        "const a = \"pre\" ++ [_]u8{9} ** 2 ++ \"post\"; // keep\nconst b = 1 * 2;\n",
        "const a = \"pre\" ++ @as([2]u8, @splat(9)) ++ \"post\"; // keep\nconst b = 1 * 2;\n",
        1,
        0,
    );
}

test "a source with no `**` comes back as itself" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const source = "const a = 2 * 3;\n";
    const result = try rewriteSource(arena_state.allocator(), source);
    try testing.expectEqual(@as(usize, 0), result.sites.len);
    try testing.expect(result.text.ptr == source.ptr);
}
