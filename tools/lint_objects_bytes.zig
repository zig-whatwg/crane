//! lint-objects-bytes: keep raw byte buffers off the `.objects` partition in `src/`.
//!
//! Crane's general heap (`src/runtime/heap/general.zig`, allocator-hardening
//! design §3.1) routes untyped `std.mem.Allocator` calls by alignment:
//! `< @alignOf(usize)` goes to `.bytes` (segregated from all pointer memory),
//! while `>= @alignOf(usize)` goes to `.objects` (pointer-bearing memory).
//! Allocating a raw byte/scalar slice (`u8`, `i8`, `u16`, `i16`, `u32`, `i32`)
//! with an explicit pointer-or-higher alignment (`>= 8`, e.g. `.@"8"`, `.@"16"`,
//! `.fromByteUnits(16)`, `@fromBackingInt(4)`, `.of(usize)`) via
//! `allocator.alignedAlloc` / `allocator.allocWithOptions` silently places
//! page-controlled raw bytes into `.objects`.
//!
//! Use `runtime.heap.allocAligned(allocator, u8, .@"16", len)` (comptime-typed
//! routing into `.bytes`) or plain `allocator.alloc(u8, len)` instead.
//!
//! What is flagged, in `src/**/*.zig` through `std.zig.Ast`:
//! 1. `*.alignedAlloc(T, align_expr, ...)` or `*.allocWithOptions(T, len, align_expr, ...)`
//!    where `T` is a raw sub-pointer scalar (`u8`, `i8`, `u16`, `i16`, `u32`, `i32`)
//!    and `align_expr` is an explicit pointer-or-higher alignment (`>= 8` bytes,
//!    log2 `>= 3`, `.of(usize|*T|...)`, `@alignOf(usize|*T|...)`).
//!    Struct-header allocations like `alignedAlloc(u8, .of(Header), ...)` or
//!    `alignedAlloc(u8, Chunk.alignment, ...)` are allowed because they allocate
//!    typed header+tail blocks, not raw byte slices.
//! 2. Direct `*.allocGeneral(.objects, ...)` or `*.cacheAlloc(..., .objects, ...)`
//!    calls passing an explicit sub-pointer alignment (`1`, `2`, `4`, `.@"1"`,
//!    `.@"2"`, `.@"4"`).
//!
//! Not scanned: `src/webidl/codegen/`, `src/webidl/impls_tmp/`, `.zig-cache/`.
//!
//! Not a ratchet: there are 0 violations in `src/`; any violation fails.
//!
//!   zig build lint-objects-bytes     (part of `zig build test`)

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
    kind: Kind,
    detail: []const u8,

    pub const Kind = enum {
        aligned_raw_bytes,
        unaligned_objects_direct,
    };
};

fn isRawSubPointerScalar(tree: *const Ast, node: Ast.Node.Index) bool {
    if (tree.nodeTag(node) != .identifier) return false;
    const name = tree.tokenSlice(tree.nodeMainToken(node));
    return std.mem.eql(u8, name, "u8") or
        std.mem.eql(u8, name, "i8") or
        std.mem.eql(u8, name, "u16") or
        std.mem.eql(u8, name, "i16") or
        std.mem.eql(u8, name, "u32") or
        std.mem.eql(u8, name, "i32");
}

fn parseIntLiteral(tree: *const Ast, node: Ast.Node.Index) ?u64 {
    switch (tree.nodeTag(node)) {
        .number_literal => {
            const parsed = std.zig.parseNumberLiteral(tree.tokenSlice(tree.nodeMainToken(node)));
            return switch (parsed) {
                .int => |v| v,
                else => null,
            };
        },
        .grouped_expression => return parseIntLiteral(tree, tree.nodeData(node).node_and_token[0]),
        else => return null,
    }
}

/// Evaluate `@intCast(N)` / `@as(T, N)` / literal `N` for log2 alignment arguments.
fn evalConstInt(tree: *const Ast, node: Ast.Node.Index, depth: u32) ?u64 {
    if (depth > 8) return null;
    if (parseIntLiteral(tree, node)) |v| return v;
    switch (tree.nodeTag(node)) {
        .builtin_call_two, .builtin_call_two_comma, .builtin_call, .builtin_call_comma => {
            var buf: [2]Ast.Node.Index = undefined;
            const params = tree.builtinCallParams(&buf, node) orelse return null;
            const name = tree.tokenSlice(tree.nodeMainToken(node));
            if (std.mem.eql(u8, name, "@intCast") and params.len == 1) {
                return evalConstInt(tree, params[0], depth + 1);
            }
            if (std.mem.eql(u8, name, "@as") and params.len == 2) {
                return evalConstInt(tree, params[1], depth + 1);
            }
            return null;
        },
        else => return null,
    }
}

fn isPointerOrWideType(tree: *const Ast, node: Ast.Node.Index) bool {
    if (tree.fullPtrType(node) != null) return true;
    switch (tree.nodeTag(node)) {
        .optional_type => return isPointerOrWideType(tree, tree.nodeData(node).node),
        .identifier => {
            const name = tree.tokenSlice(tree.nodeMainToken(node));
            return std.mem.eql(u8, name, "usize") or
                std.mem.eql(u8, name, "isize") or
                std.mem.eql(u8, name, "u64") or
                std.mem.eql(u8, name, "i64") or
                std.mem.eql(u8, name, "u128") or
                std.mem.eql(u8, name, "i128") or
                std.mem.eql(u8, name, "f64");
        },
        else => return false,
    }
}

/// Whether `align_node` explicitly requests pointer-or-higher alignment (`>= 8`
/// bytes on 64-bit) for a raw byte buffer, routing it to `.objects`.
fn isExplicitPointerOrHigherAlign(tree: *const Ast, align_node: Ast.Node.Index) bool {
    if (evalConstInt(tree, align_node, 0)) |v| return v >= 8;

    switch (tree.nodeTag(align_node)) {
        .enum_literal => {
            // `.@"8"`, `.@"16"`, `.@"32"`, ...
            const raw = tree.tokenSlice(tree.nodeMainToken(align_node));
            if (std.mem.startsWith(u8, raw, "@\"") and std.mem.endsWith(u8, raw, "\"") and raw.len > 3) {
                const digits = raw[2 .. raw.len - 1];
                const v = std.fmt.parseInt(u64, digits, 10) catch return false;
                return v >= 8;
            }
            return false;
        },
        .builtin_call_two, .builtin_call_two_comma, .builtin_call, .builtin_call_comma => {
            var buf: [2]Ast.Node.Index = undefined;
            const params = tree.builtinCallParams(&buf, align_node) orelse return false;
            const name = tree.tokenSlice(tree.nodeMainToken(align_node));
            if ((std.mem.eql(u8, name, "@fromBackingInt") or std.mem.eql(u8, name, "@enumFromInt")) and params.len == 1) {
                // `std.mem.Alignment` backing int is log2(alignment): >= 3 means >= 8 bytes.
                if (evalConstInt(tree, params[0], 0)) |log2| return log2 >= 3;
            }
            if (std.mem.eql(u8, name, "@alignOf") and params.len == 1) {
                return isPointerOrWideType(tree, params[0]);
            }
            return false;
        },
        else => {},
    }

    // Method/helper calls: `.fromByteUnits(N)` (N >= 8), `.of(usize|*T|...)`.
    var call_buf: [1]Ast.Node.Index = undefined;
    if (tree.fullCall(&call_buf, align_node)) |call| {
        const method = calleeMethodName(tree, call.ast.fn_expr) orelse return false;
        if (std.mem.eql(u8, method, "fromByteUnits") and call.ast.params.len == 1) {
            if (evalConstInt(tree, call.ast.params[0], 0)) |v| return v >= 8;
        }
        if (std.mem.eql(u8, method, "of") and call.ast.params.len == 1) {
            return isPointerOrWideType(tree, call.ast.params[0]);
        }
    }
    return false;
}

/// Whether `align_node` is an explicit sub-pointer alignment (`1`, `2`, `4`,
/// `.@"1"`, `.@"2"`, `.@"4"`).
fn isExplicitSubPointerAlign(tree: *const Ast, align_node: Ast.Node.Index) bool {
    if (evalConstInt(tree, align_node, 0)) |v| return v == 1 or v == 2 or v == 4;
    if (tree.nodeTag(align_node) == .enum_literal) {
        const raw = tree.tokenSlice(tree.nodeMainToken(align_node));
        if (std.mem.startsWith(u8, raw, "@\"") and std.mem.endsWith(u8, raw, "\"") and raw.len > 3) {
            const digits = raw[2 .. raw.len - 1];
            const v = std.fmt.parseInt(u64, digits, 10) catch return false;
            return v == 1 or v == 2 or v == 4;
        }
    }
    return false;
}

fn calleeMethodName(tree: *const Ast, fn_expr: Ast.Node.Index) ?[]const u8 {
    return switch (tree.nodeTag(fn_expr)) {
        .field_access => tree.tokenSlice(tree.nodeData(fn_expr).node_and_token[1]),
        .enum_literal => tree.tokenSlice(tree.nodeMainToken(fn_expr)),
        .identifier => tree.tokenSlice(tree.nodeMainToken(fn_expr)),
        else => null,
    };
}

fn isObjectsEnumLiteral(tree: *const Ast, node: Ast.Node.Index) bool {
    return tree.nodeTag(node) == .enum_literal and std.mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(node)), "objects");
}

/// Every raw-bytes-off-`.objects` violation in `source`. `detail` slices borrow from `source`.
pub fn findings(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(Finding) {
    var tree = try Ast.parse(gpa, source, .{ .mode = .zig });
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return error.ParseError;

    var found: std.ArrayList(Finding) = .empty;
    errdefer found.deinit(gpa);

    const node_count: u32 = @intCast(tree.nodes.len);
    for (1..node_count) |raw_idx| {
        const node: Ast.Node.Index = @fromBackingInt(@intCast(raw_idx));
        var call_buf: [1]Ast.Node.Index = undefined;
        const call = tree.fullCall(&call_buf, node) orelse continue;
        const method = calleeMethodName(&tree, call.ast.fn_expr) orelse continue;

        if (std.mem.eql(u8, method, "alignedAlloc") and call.ast.params.len == 3) {
            if (isRawSubPointerScalar(&tree, call.ast.params[0]) and isExplicitPointerOrHigherAlign(&tree, call.ast.params[1])) {
                const loc = tree.tokenLocation(0, tree.firstToken(node));
                try found.append(gpa, .{
                    .line = loc.line + 1,
                    .column = loc.column + 1,
                    .kind = .aligned_raw_bytes,
                    .detail = tree.getNodeSource(node),
                });
            }
        } else if (std.mem.eql(u8, method, "allocWithOptions") and call.ast.params.len >= 3) {
            if (isRawSubPointerScalar(&tree, call.ast.params[0]) and isExplicitPointerOrHigherAlign(&tree, call.ast.params[2])) {
                const loc = tree.tokenLocation(0, tree.firstToken(node));
                try found.append(gpa, .{
                    .line = loc.line + 1,
                    .column = loc.column + 1,
                    .kind = .aligned_raw_bytes,
                    .detail = tree.getNodeSource(node),
                });
            }
        } else if (std.mem.eql(u8, method, "allocGeneral") and call.ast.params.len >= 3) {
            if (isObjectsEnumLiteral(&tree, call.ast.params[0]) and isExplicitSubPointerAlign(&tree, call.ast.params[2])) {
                const loc = tree.tokenLocation(0, tree.firstToken(node));
                try found.append(gpa, .{
                    .line = loc.line + 1,
                    .column = loc.column + 1,
                    .kind = .unaligned_objects_direct,
                    .detail = tree.getNodeSource(node),
                });
            }
        } else if (std.mem.eql(u8, method, "cacheAlloc") and call.ast.params.len >= 4) {
            if (isObjectsEnumLiteral(&tree, call.ast.params[1]) and isExplicitSubPointerAlign(&tree, call.ast.params[3])) {
                const loc = tree.tokenLocation(0, tree.firstToken(node));
                try found.append(gpa, .{
                    .line = loc.line + 1,
                    .column = loc.column + 1,
                    .kind = .unaligned_objects_direct,
                    .detail = tree.getNodeSource(node),
                });
            }
        }
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
            switch (f.kind) {
                .aligned_raw_bytes => try out.print("{s}:{d}:{d}: error: raw byte/scalar slice allocated with explicit pointer alignment routes raw bytes into .objects; use runtime.heap.allocAligned(..., .bytes) or plain alloc() ({s})\n", .{ path, f.line, f.column, f.detail }),
                .unaligned_objects_direct => try out.print("{s}:{d}:{d}: error: direct sub-pointer aligned allocation into .objects places raw bytes in pointer memory ({s})\n", .{ path, f.line, f.column, f.detail }),
            }
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
        try out.print("\nlint-objects-bytes: {d} raw-bytes-in-.objects violation(s) in src/ (tools/lint_objects_bytes.zig).\n", .{violations});
        try out.flush();
        std.process.exit(1);
    }
    try out.print("lint-objects-bytes: 0 raw-bytes-in-.objects violations in src/.\n", .{});
}

// ============================================================================
// Tests (red and green fixtures)
// ============================================================================

const testing = std.testing;

test "red fixtures: raw byte slices with explicit pointer alignment and unaligned direct .objects calls are flagged" {
    var found = try findings(testing.allocator,
        \\fn bad(a: std.mem.Allocator, eng: anytype, cache: anytype) !void {
        \\    _ = try a.alignedAlloc(u8, .@"8", 64);
        \\    _ = try a.alignedAlloc(u8, .@"16", 64);
        \\    _ = try a.alignedAlloc(u8, @fromBackingInt(@intCast(4)), 64);
        \\    _ = try a.alignedAlloc(u16, .fromByteUnits(16), 32);
        \\    _ = try a.alignedAlloc(u8, .of(usize), 64);
        \\    _ = try a.allocWithOptions(u8, 64, 16, null);
        \\    _ = try eng.allocGeneral(.objects, 64, 1, 0);
        \\    _ = try eng.cacheAlloc(cache, .objects, 64, .@"1", 0);
        \\}
    );
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 8), found.items.len);
    for (found.items[0..6]) |f| try testing.expectEqual(Finding.Kind.aligned_raw_bytes, f.kind);
    for (found.items[6..8]) |f| try testing.expectEqual(Finding.Kind.unaligned_objects_direct, f.kind);
}

test "green fixtures: struct-header alignedAlloc, sub-pointer alignedAlloc, and heap.allocAligned are allowed" {
    var found = try findings(testing.allocator,
        \\fn good(a: std.mem.Allocator, eng: anytype, cache: anytype) !void {
        \\    _ = try a.alloc(u8, 64);
        \\    _ = try a.alignedAlloc(u8, .@"4", 64);
        \\    _ = try a.alignedAlloc(u8, .of(CustomHeader), 64);
        \\    _ = try a.alignedAlloc(u8, Chunk.alignment, 64);
        \\    _ = try a.alignedAlloc(MyStruct, .@"16", 4);
        \\    _ = try heap.allocAligned(a, u8, .@"16", 64);
        \\    _ = try eng.allocGeneral(.bytes, 64, 16, 0);
        \\    _ = try eng.allocGeneral(.objects, 64, 8, 0);
        \\    _ = try eng.cacheAlloc(cache, .objects, 64, .@"8", 0);
        \\}
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
    try tmp.dir.writeFile(io, .{ .sub_path = "src/dom/bad.zig", .data = "fn f(a: anytype) !void { _ = try a.alignedAlloc(u8, .@\"16\", 64); }\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/webidl/codegen/gen.zig", .data = "fn f(a: anytype) !void { _ = try a.alignedAlloc(u8, .@\"16\", 64); }\n" });
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    const count = try check(io, testing.allocator, tmp.dir, &w);
    try testing.expectEqual(@as(usize, 1), count);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "src/dom/bad.zig:1:34: error: raw byte/scalar slice allocated with explicit pointer alignment") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "codegen") == null);
}
