//! lint-stack-arrays: no function keeps an array over 64 KiB on its stack,
//! as a ratchet.
//!
//! An optimized build inlines a callee into its caller, and the caller's
//! prologue then reserves the callee's locals whether or not the callee
//! runs. tools/repl.zig's serveMcp kept a 1 MiB and a 64 KiB stdio buffer on
//! the stack; inlined into main, it made main reserve 1,125,008 bytes on
//! every run, --mcp or not. V8 sets its stack limit from the thread's stack
//! start (stack-guard.cc), so every script of the plain release console threw
//! "Maximum call stack size exceeded" (lane rc8, 2026-11-24). A large buffer
//! comes from an allocator (`alloc` + `defer free`), or lives in its owner.
//!
//! What is flagged, in src/**/*.zig and tools/**/*.zig through std.zig.Ast: a
//! `var` declared in a function or test body (not a container's member, not
//! `comptime`) whose type is an array - `[N]T`, `[N:s]T`, nested - of more
//! than `limit_bytes`. N is evaluated from integer literals, `<<`, `*`, `+`,
//! `-`, parentheses and the file's own container-level constants; T's size
//! is known for the integer, float and bool types, pointers (8) and slices
//! (16), and taken as 1 byte for any other type (so an array is flagged at
//! least when its count alone is over the limit). A count it cannot evaluate
//! is not flagged. `const` locals are not looked at: a comptime-known one is
//! static data, not stack.
//!
//! Not scanned: src/webidl/impls_tmp/ (codegen's stubs, not built), caches.
//!
//! A ratchet: tools/stack_arrays_baseline.txt records each existing array,
//! `path Function.variable bytes`. A new one, or one grown, fails; the
//! baseline only goes down:
//!
//!   zig build lint-stack-arrays                  (part of `zig build test`)
//!   zig build lint-stack-arrays -- --list        every array, with its line
//!   zig build lint-stack-arrays -- --update      record fewer or smaller ones

const std = @import("std");
const Ast = std.zig.Ast;
const stdout_stream = @import("stdout_stream.zig");

/// Over this many bytes, a stack array is flagged.
pub const limit_bytes: u64 = 64 * 1024;

const scanned_roots = [_][]const u8{ "src", "tools" };

const exempt_prefixes = [_][]const u8{
    "src/webidl/impls_tmp/",
};

pub const baseline_path = "tools/stack_arrays_baseline.txt";

/// Whether `path` (from the repo root, `/`-separated) is held to the rule.
pub fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    if (std.mem.indexOf(u8, path, ".zig-cache/") != null) return false;
    for (exempt_prefixes) |prefix| if (std.mem.startsWith(u8, path, prefix)) return false;
    for (scanned_roots) |root| if (std.mem.startsWith(u8, path, root) and path.len > root.len and path[root.len] == '/') return true;
    return false;
}

/// One stack array over the limit.
pub const Finding = struct {
    /// "Function.variable" (a test's body: "test.variable").
    name: []const u8,
    bytes: u64,
    line: u32,
};

const Range = struct { first: Ast.TokenIndex, last: Ast.TokenIndex, name: []const u8 };

/// Every stack array over the limit in `source`, in source order; names in
/// `arena`. A file that does not parse is an error.
pub fn findings(arena: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(Finding) {
    var tree = try Ast.parse(arena, source, .{ .mode = .zig });
    defer tree.deinit(arena);
    if (tree.errors.len > 0) return error.ParseError;

    // The bodies a local lives in, the container members (static, not
    // stack), and the file's container-level constants.
    var bodies: std.ArrayList(Range) = .empty;
    var members: std.AutoHashMapUnmanaged(Ast.Node.Index, void) = .empty;
    var constants: std.StringHashMapUnmanaged(Ast.Node.Index) = .empty;
    const node_count: u32 = @intCast(tree.nodes.len);
    var i: u32 = 0;
    while (i < node_count) : (i += 1) {
        const node: Ast.Node.Index = @fromBackingInt(@intCast(i));
        switch (tree.nodeTag(node)) {
            .fn_decl => {
                const fn_token = tree.nodeMainToken(node);
                const name: []const u8 = if (tree.tokenTag(fn_token + 1) == .identifier) tree.tokenSlice(fn_token + 1) else "fn";
                try bodies.append(arena, .{ .first = tree.firstToken(node), .last = tree.lastToken(node), .name = name });
            },
            .test_decl => try bodies.append(arena, .{ .first = tree.firstToken(node), .last = tree.lastToken(node), .name = "test" }),
            else => {},
        }
        var buf: [2]Ast.Node.Index = undefined;
        const container = tree.fullContainerDecl(&buf, node) orelse if (i == 0) Ast.full.ContainerDecl{
            .layout_token = null,
            .ast = .{ .main_token = 0, .enum_token = null, .members = tree.rootDecls(), .arg = .none },
        } else continue;
        for (container.ast.members) |member| {
            try members.put(arena, member, {});
            if (tree.fullVarDecl(member)) |vd| {
                if (!std.mem.eql(u8, tree.tokenSlice(vd.ast.mut_token), "const")) continue;
                const init = vd.ast.init_node.unwrap() orelse continue;
                try constants.put(arena, tree.tokenSlice(vd.ast.mut_token + 1), init);
            }
        }
    }

    var out: std.ArrayList(Finding) = .empty;
    i = 0;
    while (i < node_count) : (i += 1) {
        const node: Ast.Node.Index = @fromBackingInt(@intCast(i));
        const vd = tree.fullVarDecl(node) orelse continue;
        if (members.contains(node)) continue;
        if (vd.comptime_token != null) continue;
        if (!std.mem.eql(u8, tree.tokenSlice(vd.ast.mut_token), "var")) continue;
        const type_node = vd.ast.type_node.unwrap() orelse continue;
        const bytes = sizeOf(&tree, type_node, &constants, 0) orelse continue;
        if (!isArray(&tree, type_node)) continue;
        if (bytes <= limit_bytes) continue;
        // The innermost body around it.
        const at = vd.ast.mut_token;
        var enclosing: ?Range = null;
        for (bodies.items) |body| {
            if (at < body.first or at > body.last) continue;
            if (enclosing == null or body.first >= enclosing.?.first) enclosing = body;
        }
        const body = enclosing orelse continue;
        try out.append(arena, .{
            .name = try std.fmt.allocPrint(arena, "{s}.{s}", .{ body.name, tree.tokenSlice(at + 1) }),
            .bytes = bytes,
            .line = @intCast(std.mem.count(u8, source[0..tree.tokenStart(at)], "\n") + 1),
        });
    }
    std.mem.sort(Finding, out.items, {}, struct {
        fn less(_: void, x: Finding, y: Finding) bool {
            return x.line < y.line;
        }
    }.less);
    return out;
}

fn isArray(tree: *const Ast, node: Ast.Node.Index) bool {
    return tree.fullArrayType(node) != null;
}

/// A type's size in bytes, when this lint knows it: an array's count times
/// its element's (an unknown element counted as 1), a known scalar's, a
/// pointer's or a slice's. Null when an array's count cannot be evaluated or
/// the type is not one of those.
fn sizeOf(tree: *const Ast, node: Ast.Node.Index, constants: *const std.StringHashMapUnmanaged(Ast.Node.Index), depth: u32) ?u64 {
    if (depth > 16) return null;
    if (tree.fullArrayType(node)) |array| {
        const count = evaluate(tree, array.ast.elem_count, constants, 0) orelse return null;
        const element = sizeOf(tree, array.ast.elem_type, constants, depth + 1) orelse 1;
        return std.math.mul(u64, count, element) catch std.math.maxInt(u64);
    }
    if (tree.fullPtrType(node)) |ptr| return if (ptr.size == .slice) 16 else 8;
    if (tree.nodeTag(node) == .identifier) return scalarSize(tree.tokenSlice(tree.nodeMainToken(node)));
    return null;
}

fn scalarSize(name: []const u8) ?u64 {
    const sizes = [_]struct { []const u8, u64 }{
        .{ "u8", 1 },    .{ "i8", 1 },    .{ "bool", 1 },  .{ "u16", 2 },   .{ "i16", 2 },
        .{ "f16", 2 },   .{ "u32", 4 },   .{ "i32", 4 },   .{ "f32", 4 },   .{ "u64", 8 },
        .{ "i64", 8 },   .{ "f64", 8 },   .{ "usize", 8 }, .{ "isize", 8 }, .{ "u128", 16 },
        .{ "i128", 16 }, .{ "f128", 16 }, .{ "u21", 4 },
    };
    for (sizes) |s| if (std.mem.eql(u8, s[0], name)) return s[1];
    return null;
}

/// An array count's value: integer literals, `<<`, `*`, `+`, `-`,
/// parentheses, and the file's container-level constants.
fn evaluate(tree: *const Ast, node: Ast.Node.Index, constants: *const std.StringHashMapUnmanaged(Ast.Node.Index), depth: u32) ?u64 {
    if (depth > 16) return null;
    switch (tree.nodeTag(node)) {
        .number_literal => return switch (std.zig.parseNumberLiteral(tree.tokenSlice(tree.nodeMainToken(node)))) {
            .int => |v| v,
            else => null,
        },
        .grouped_expression => return evaluate(tree, tree.nodeData(node).node_and_token[0], constants, depth + 1),
        .identifier => {
            const init = constants.get(tree.tokenSlice(tree.nodeMainToken(node))) orelse return null;
            return evaluate(tree, init, constants, depth + 1);
        },
        .shl, .mul, .add, .sub => {
            const operands = tree.nodeData(node).node_and_node;
            const a = evaluate(tree, operands[0], constants, depth + 1) orelse return null;
            const b = evaluate(tree, operands[1], constants, depth + 1) orelse return null;
            return switch (tree.nodeTag(node)) {
                .shl => if (b < 64) std.math.shlExact(u64, a, @intCast(b)) catch null else null,
                .mul => std.math.mul(u64, a, b) catch null,
                .add => std.math.add(u64, a, b) catch null,
                .sub => std.math.sub(u64, a, b) catch null,
                else => unreachable,
            };
        },
        else => return null,
    }
}

// ============================================================================
// The baseline
// ============================================================================

/// "path Function.variable" to bytes.
pub const Counts = std.StringHashMapUnmanaged(u64);

pub fn parseBaseline(arena: std.mem.Allocator, text: []const u8) !Counts {
    var counts: Counts = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const last_space = std.mem.lastIndexOfScalar(u8, line, ' ') orelse return error.BadBaseline;
        const bytes = std.fmt.parseInt(u64, line[last_space + 1 ..], 10) catch return error.BadBaseline;
        try counts.put(arena, try arena.dupe(u8, line[0..last_space]), bytes);
    }
    return counts;
}

const header =
    \\# Stack arrays over 64 KiB in a function or test body in src/ and tools/:
    \\# path Function.variable bytes (tools/lint_stack_arrays.zig). An optimized build
    \\# inlines a callee into its caller, whose prologue then reserves the callee's
    \\# locals on every call; V8 sets its stack limit from the thread's stack start, so a
    \\# reservation in main broke every script of the release console (lane rc8,
    \\# 2026-11-24). Take a large buffer from an allocator instead. A ratchet -
    \\# `zig build lint-stack-arrays`, part of `zig build test`, fails on a new or grown
    \\# array; after removing some, `zig build lint-stack-arrays -- --update`. Never raise
    \\# it by hand.
    \\
;

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

pub fn formatBaseline(arena: std.mem.Allocator, counts: *const Counts) ![]u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    var it = counts.keyIterator();
    while (it.next()) |key| try keys.append(arena, key.*);
    std.mem.sort([]const u8, keys.items, {}, lessThan);
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, header);
    for (keys.items) |key| try out.print(arena, "{s} {d}\n", .{ key, counts.get(key).? });
    return out.items;
}

/// The keys of `current` that `baseline` lacks or records smaller.
pub fn regressions(arena: std.mem.Allocator, baseline: *const Counts, current: *const Counts) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = current.iterator();
    while (it.next()) |e| {
        const recorded = baseline.get(e.key_ptr.*) orelse {
            try out.append(arena, e.key_ptr.*);
            continue;
        };
        if (e.value_ptr.* > recorded) try out.append(arena, e.key_ptr.*);
    }
    std.mem.sort([]const u8, out.items, {}, lessThan);
    return out.items;
}

// ============================================================================
// The tool
// ============================================================================

const Site = struct { path: []const u8, line: u32, key: []const u8, bytes: u64 };

fn scan(arena: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, current: *Counts, sites: *std.ArrayList(Site)) !void {
    for (scanned_roots) |root_name| {
        var root = dir.openDir(io, root_name, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer root.close(io);
        var walker = try root.walk(arena);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind != .file) continue;
            const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ root_name, entry.path });
            std.mem.replaceScalar(u8, path, '\\', '/');
            if (!isScanned(path)) continue;
            const source = try dir.readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
            const found = findings(arena, source) catch |err| switch (err) {
                error.ParseError => {
                    std.debug.print("lint-stack-arrays: {s} does not parse\n", .{path});
                    return err;
                },
                else => return err,
            };
            for (found.items) |f| {
                var key = try std.fmt.allocPrint(arena, "{s} {s}", .{ path, f.name });
                // Two of one name in a file: numbered in source order.
                var n: u32 = 2;
                while (current.contains(key)) : (n += 1) key = try std.fmt.allocPrint(arena, "{s} {s}#{d}", .{ path, f.name, n });
                try current.put(arena, key, f.bytes);
                try sites.append(arena, .{ .path = path, .line = f.line, .key = key, .bytes = f.bytes });
            }
        }
    }
}

fn usage() noreturn {
    std.debug.print("usage: lint_stack_arrays [--update | --list]\n", .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var update = false;
    var list = false;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) update = true else if (std.mem.eql(u8, arg, "--list")) list = true else usage();
    }

    const cwd = std.Io.Dir.cwd();
    var current: Counts = .empty;
    var sites: std.ArrayList(Site) = .empty;
    try scan(arena, io, cwd, &current, &sites);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    if (list) {
        for (sites.items) |site| try out.print("{s}:{d}: {s} {d} bytes\n", .{ site.path, site.line, site.key[site.path.len + 1 ..], site.bytes });
        return;
    }

    const baseline_text: ?[]const u8 = cwd.readFileAlloc(io, baseline_path, arena, .limited(16 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    var baseline = if (baseline_text) |text| try parseBaseline(arena, text) else Counts.empty;
    const worse = try regressions(arena, &baseline, &current);

    if (update) {
        // The first record takes what there is; after it, only fewer or
        // smaller.
        if (baseline_text != null and worse.len > 0) {
            for (worse) |key| try out.print("lint-stack-arrays: refusing to record {s} ({d} bytes): new or grown\n", .{ key, current.get(key).? });
            try out.flush();
            std.process.exit(1);
        }
        try cwd.writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("lint-stack-arrays: recorded {d} stack array(s) over 64 KiB in {s}\n", .{ current.count(), baseline_path });
        return;
    }

    if (worse.len > 0) {
        for (worse) |key| {
            for (sites.items) |site| if (std.mem.eql(u8, site.key, key)) {
                try out.print("{s}:{d}: error: a {d}-byte array on the stack ({s}) - an optimized build can reserve it in every caller's prologue; take it from an allocator (alloc + defer free) instead (tools/lint_stack_arrays.zig)\n", .{ site.path, site.line, site.bytes, key[site.path.len + 1 ..] });
            };
        }
        try out.print("\nlint-stack-arrays: {d} stack array(s) over 64 KiB not in {s}.\n", .{ worse.len, baseline_path });
        try out.flush();
        std.process.exit(1);
    }
    try out.print("lint-stack-arrays: {d} stack array(s) over 64 KiB, none above the baseline.\n", .{current.count()});
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn findingsOf(arena: std.mem.Allocator, source: [:0]const u8) ![]const Finding {
    return (try findings(arena, source)).items;
}

test "serveMcp's shape is flagged: a function's 1 MiB and 64 KiB + 1 buffers, not one of 64 KiB" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const found = try findingsOf(arena,
        \\fn serveMcp() void {
        \\    var in_buffer: [1 << 20]u8 = undefined;
        \\    var out_buffer: [64 * 1024]u8 = undefined;
        \\    var over: [64 * 1024 + 1]u8 = undefined;
        \\    _ = .{ &in_buffer, &out_buffer, &over };
        \\}
    );
    try testing.expectEqual(@as(usize, 2), found.len);
    try testing.expectEqualStrings("serveMcp.in_buffer", found[0].name);
    try testing.expectEqual(@as(u64, 1 << 20), found[0].bytes);
    try testing.expectEqual(@as(u32, 2), found[0].line);
    try testing.expectEqualStrings("serveMcp.over", found[1].name);
}

test "element sizes, nested arrays, the file's constants; container members, consts and comptime vars are not stack" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const found = try findingsOf(arena,
        \\const page = 4096;
        \\const pages = page * 4;
        \\var global: [1 << 20]u8 = undefined;
        \\const S = struct {
        \\    var member: [1 << 20]u8 = undefined;
        \\    fn method() void {
        \\        var words: [pages + 1]u32 = undefined;
        \\        var small: [pages]u8 = undefined;
        \\        var grid: [256][256]u16 = undefined;
        \\        var ptrs: [(9000)]*u8 = undefined;
        \\        var records: [70000]Record = undefined;
        \\        var unknown: [n]u8 = undefined;
        \\        const table: [1 << 20]u8 = @splat(0);
        \\        comptime var at_compile: [1 << 20]u8 = undefined;
        \\        _ = .{ &words, &small, &grid, &ptrs, &records, &unknown, &table, &at_compile };
        \\    }
        \\};
        \\test "big" {
        \\    var buffer: [100000]u8 = undefined;
        \\    _ = &buffer;
        \\}
    );
    var names: std.ArrayList([]const u8) = .empty;
    for (found) |f| try names.append(arena, f.name);
    const want = [_][]const u8{ "method.words", "method.grid", "method.ptrs", "method.records", "test.buffer" };
    try testing.expectEqual(want.len, names.items.len);
    for (want, names.items) |w, got| try testing.expectEqualStrings(w, got);
    try testing.expectEqual(@as(u64, (4096 * 4 + 1) * 4), found[0].bytes);
    try testing.expectEqual(@as(u64, 256 * 256 * 2), found[1].bytes);
    try testing.expectEqual(@as(u64, 9000 * 8), found[2].bytes);
    try testing.expectEqual(@as(u64, 70000), found[3].bytes);
}

test "the baseline: a new or grown array regresses, a removed or smaller one does not" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var baseline = try parseBaseline(arena, "# header\nsrc/a.zig f.x 70000\nsrc/b.zig g.y 80000\n");
    var current: Counts = .empty;
    try current.put(arena, "src/a.zig f.x", 70000);
    try current.put(arena, "src/b.zig g.y", 90000);
    try current.put(arena, "tools/c.zig h.z", 66000);
    const worse = try regressions(arena, &baseline, &current);
    try testing.expectEqual(@as(usize, 2), worse.len);
    try testing.expectEqualStrings("src/b.zig g.y", worse[0]);
    try testing.expectEqualStrings("tools/c.zig h.z", worse[1]);
    const text = try formatBaseline(arena, &current);
    const again = try parseBaseline(arena, text);
    try testing.expectEqual(@as(u64, 66000), again.get("tools/c.zig h.z").?);
}

test "src/ and tools/ are scanned, codegen's stubs and caches are not" {
    try testing.expect(isScanned("src/dom/tree.zig"));
    try testing.expect(isScanned("tools/repl.zig"));
    try testing.expect(!isScanned("src/webidl/impls_tmp/Node.zig"));
    try testing.expect(!isScanned("tests/html/x_test.zig"));
    try testing.expect(!isScanned("src/.zig-cache/o/x.zig"));
    try testing.expect(!isScanned("tools/notes.md"));
    try testing.expect(!isScanned("srcx/a.zig"));
}
