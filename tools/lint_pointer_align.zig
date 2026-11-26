//! lint-pointer-align: no pointer-bearing struct or union field declared
//! `align(1)`, `align(2)` (or `align(4)`) in `src/`.
//!
//! Crane's general heap (`src/runtime/heap/general.zig`, allocator-hardening
//! batch B item 2 & batch C item 4) routes allocations by alignment: below a
//! pointer's alignment (`< @alignOf(usize)`) goes to `.bytes` (no zeroing, no
//! quarantine, re-classed spans); at or above `@alignOf(usize)` goes to
//! `.objects`. Zig guarantees any struct with a pointer field has at least
//! pointer alignment UNLESS a field explicitly downgrades its alignment with
//! `align(1)`, `align(2)` (or `align(4)` on 64-bit targets).
//!
//! What is flagged, in `src/**/*.zig` through `std.zig.Ast`:
//! - Any container field (`struct` / `union` field) with an explicit
//!   `align(N)` where `N` is 1, 2, or 4 AND whose type is a pointer, slice,
//!   optional pointer/slice, array of pointers, or non-scalar composite type.
//! - Pointee alignment (`p: *align(1) u8`) does NOT lower the field's own
//!   alignment (still 8 bytes on 64-bit) and is allowed.
//! - Scalar fields (`x: u32 align(1)`, `buf: [16]u8 align(1)`) hold no
//!   pointers and are allowed.
//!
//! Not scanned: `src/webidl/codegen/`, `src/webidl/impls_tmp/`, `.zig-cache/`.
//!
//! Not a ratchet: there are 0 violations in `src/`; any violation fails.
//!
//!   zig build lint-pointer-align     (part of `zig build test`)

const std = @import("std");
const Ast = std.zig.Ast;
const stdout_stream = @import("stdout_stream.zig");

const scanned_root = "src";

const exempt_prefixes = [_][]const u8{
    "src/webidl/codegen/",
    "src/webidl/impls_tmp/",
};

pub fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    if (!std.mem.startsWith(u8, path, scanned_root ++ "/")) return false;
    if (std.mem.indexOf(u8, path, ".zig-cache/") != null) return false;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return false;
    return true;
}

pub const Finding = struct {
    line: usize,
    column: usize,
    alignment: u64,
    field_name: []const u8,
};

/// Whether `type_node` is a scalar type guaranteed to hold no pointers.
fn isPointerFreeScalar(tree: *const Ast, type_node: Ast.Node.Index, depth: u32) bool {
    if (depth > 16) return false;
    if (tree.fullPtrType(type_node) != null) return false;
    if (tree.fullArrayType(type_node)) |arr| {
        return isPointerFreeScalar(tree, arr.ast.elem_type, depth + 1);
    }
    switch (tree.nodeTag(type_node)) {
        .optional_type => return isPointerFreeScalar(tree, tree.nodeData(type_node).node, depth + 1),
        .error_union => return isPointerFreeScalar(tree, tree.nodeData(type_node).node_and_node[1], depth + 1),
        .identifier => {
            const name = tree.tokenSlice(tree.nodeMainToken(type_node));
            return isScalarName(name);
        },
        else => return false,
    }
}

fn isScalarName(name: []const u8) bool {
    const scalars = [_][]const u8{
        "bool",         "void",         "noreturn",       "anyerror",
        "f16",          "f32",          "f64",            "f80",
        "f128",         "usize",        "isize",          "c_char",
        "c_short",      "c_ushort",     "c_int",          "c_uint",
        "c_long",       "c_ulong",      "c_longlong",     "c_ulonglong",
        "c_longdouble", "comptime_int", "comptime_float",
    };
    for (scalars) |s| if (std.mem.eql(u8, name, s)) return true;
    // Arbitrary-width integers: u0..u65535, i0..i65535.
    if (name.len >= 2 and (name[0] == 'u' or name[0] == 'i')) {
        for (name[1..]) |ch| if (!std.ascii.isDigit(ch)) return false;
        return true;
    }
    return false;
}

fn evalSmallAlign(tree: *const Ast, align_node: Ast.Node.Index) ?u64 {
    switch (tree.nodeTag(align_node)) {
        .number_literal => {
            const parsed = std.zig.parseNumberLiteral(tree.tokenSlice(tree.nodeMainToken(align_node)));
            return switch (parsed) {
                .int => |v| v,
                else => null,
            };
        },
        .grouped_expression => return evalSmallAlign(tree, tree.nodeData(align_node).node_and_token[0]),
        else => return null,
    }
}

/// Every pointer-bearing container field declared `align(1)`, `align(2)`, or
/// `align(4)` in `source`. Field names borrow from `source`.
pub fn findings(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(Finding) {
    var tree = try Ast.parse(gpa, source, .{ .mode = .zig });
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return error.ParseError;

    var found: std.ArrayList(Finding) = .empty;
    errdefer found.deinit(gpa);

    const node_count: u32 = @intCast(tree.nodes.len);
    for (1..node_count) |raw_idx| {
        const node: Ast.Node.Index = @fromBackingInt(@intCast(raw_idx));
        const field = tree.fullContainerField(node) orelse continue;
        if (field.ast.tuple_like) continue;
        const align_node = field.ast.align_expr.unwrap() orelse continue;
        const alignment = evalSmallAlign(&tree, align_node) orelse continue;
        if (alignment != 1 and alignment != 2 and alignment != 4) continue;
        const type_node = field.ast.type_expr.unwrap() orelse continue;
        if (isPointerFreeScalar(&tree, type_node, 0)) continue;

        const tok = field.ast.main_token;
        const loc = tree.tokenLocation(0, tok);
        try found.append(gpa, .{
            .line = loc.line + 1,
            .column = loc.column + 1,
            .alignment = alignment,
            .field_name = tree.tokenSlice(tok),
        });
    }
    return found;
}

pub fn check(io: std.Io, gpa: std.mem.Allocator, dir: std.Io.Dir, out: *std.Io.Writer) !usize {
    var violations: usize = 0;
    var root = dir.openDir(io, scanned_root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    defer root.close(io);
    var walker = try root.walk(gpa);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ scanned_root, entry.path });
        defer gpa.free(path);
        std.mem.replaceScalar(u8, path, '\\', '/');
        if (!isScanned(path)) continue;
        const source = try dir.readFileAllocOptions(io, path, gpa, .limited(64 << 20), .of(u8), 0);
        defer gpa.free(source);
        var found = try findings(gpa, source);
        defer found.deinit(gpa);
        for (found.items) |f| {
            violations += 1;
            try out.print("{s}:{d}:{d}: error: pointer-bearing field '{s}' declared align({d}) would lower its struct's alignment below @alignOf(usize) and route it to the .bytes partition instead of .objects (src/runtime/heap/general.zig)\n", .{ path, f.line, f.column, f.field_name, f.alignment });
        }
    }
    return violations;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const violations = try check(io, init.gpa, std.Io.Dir.cwd(), out);
    if (violations > 0) {
        try out.print("\nlint-pointer-align: {d} pointer-bearing field(s) with align(1|2|4) in src/ (tools/lint_pointer_align.zig).\n", .{violations});
        try out.flush();
        std.process.exit(1);
    }
    try out.print("lint-pointer-align: 0 pointer-bearing fields with align(1|2|4) in src/.\n", .{});
}

// ============================================================================
// Tests (red and green fixtures)
// ============================================================================

const testing = std.testing;

test "red fixtures: pointer, slice, optional pointer, array of pointers, and composite fields with align(1|2|4) are flagged" {
    var found = try findings(testing.allocator,
        \\const Bad = struct {
        \\    raw: *u8 align(1),
        \\    opt: ?*anyopaque align(2),
        \\    slice: []const u8 align(1),
        \\    arr: [4]*u8 align(2),
        \\    nested: OtherStruct align(1),
        \\    four: *u8 align(4),
        \\};
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 6), found.items.len);
    try testing.expectEqualStrings("raw", found.items[0].field_name);
    try testing.expectEqual(@as(u64, 1), found.items[0].alignment);
    try testing.expectEqualStrings("opt", found.items[1].field_name);
    try testing.expectEqual(@as(u64, 2), found.items[1].alignment);
    try testing.expectEqualStrings("slice", found.items[2].field_name);
    try testing.expectEqualStrings("arr", found.items[3].field_name);
    try testing.expectEqualStrings("nested", found.items[4].field_name);
    try testing.expectEqualStrings("four", found.items[5].field_name);
    try testing.expectEqual(@as(u64, 4), found.items[5].alignment);
}

test "green fixtures: pointee align(1), pointer-aligned fields, and scalar fields with align(1|2) are allowed" {
    var found = try findings(testing.allocator,
        \\const Good = struct {
        \\    pointee: *align(1) u8,
        \\    fn_ptr: ?*align(1) const fn (?*anyopaque) callconv(.c) void,
        \\    normal: *u8,
        \\    eight: *u8 align(8),
        \\    scalar: u32 align(1),
        \\    bytes: [16]u8 align(1),
        \\    opt_scalar: ?u64 align(2),
        \\};
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), found.items.len);
}

test "check reports violations under src/ and skips codegen" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;
    try tmp.dir.createDirPath(io, "src/dom");
    try tmp.dir.createDirPath(io, "src/webidl/codegen");
    try tmp.dir.writeFile(io, .{ .sub_path = "src/dom/bad.zig", .data = "const S = struct { p: *u8 align(1) };\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/webidl/codegen/gen.zig", .data = "const S = struct { p: *u8 align(1) };\n" });
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    const count = try check(io, testing.allocator, tmp.dir, &w);
    try testing.expectEqual(@as(usize, 1), count);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "src/dom/bad.zig:1:20: error: pointer-bearing field 'p' declared align(1)") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "codegen") == null);
}
