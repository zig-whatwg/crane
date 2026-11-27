//! lint-test-inputs: every `readFileAlloc` of a checked-in repository file in
//! `tests/` must be declared in `build.zig`'s `addSuiteRuntimeInputs` (either as
//! an `addFileInput`, a covering `addRunInputTree`, or `run.has_side_effects = true`).
//!
//! Why (queue-0.1-audit.md; lane a11y1 caba1dcf7):
//! `tools/test_launcher` keys cached test runs on the test executable's bytes.
//! A test that reads a checked-in data file at run time (`readFileAlloc`)
//! without declaring it as a Run-step input stays CACHED when only that data
//! file changes — so a data-only commit can pass `zig build test` while
//! breaking the test on `main`.
//!
//! Upstream submodule fixtures under `tests/wpt/` are intentionally excluded
//! (per `build.zig` `addSuiteRuntimeInputs`: worktrees leave that submodule
//! uninitialized and tests skip when absent). Scratch paths (`tmp/`, `/tmp/`)
//! and negative-test non-existent paths (`FileNotFound`) are also ignored.
//!
//! Not a ratchet: 0 violations allowed.
//!
//!   zig build lint-test-inputs     (part of `zig build test`)

const std = @import("std");
const Ast = std.zig.Ast;
const stdout_stream = @import("stdout_stream.zig");

const repo_prefixes = [_][]const u8{
    "src/",
    "tests/",
    "tools/",
    "specs/",
    "docs/",
    "include/",
    "scripts/",
};

pub const SuiteInputs = struct {
    suite_dir: []const u8,
    uncached: bool = false,
    files: std.ArrayList([]const u8) = .empty,
    trees: std.ArrayList([]const u8) = .empty,

    pub fn deinit(self: *SuiteInputs, gpa: std.mem.Allocator) void {
        self.files.deinit(gpa);
        self.trees.deinit(gpa);
    }

    pub fn covers(self: *const SuiteInputs, path: []const u8) bool {
        if (self.uncached) return true;
        for (self.files.items) |f| {
            if (std.mem.eql(u8, f, path)) return true;
        }
        for (self.trees.items) |tree| {
            const clean = std.mem.trimEnd(u8, tree, "/");
            if (std.mem.eql(u8, path, clean)) return true;
            if (path.len > clean.len and std.mem.startsWith(u8, path, clean) and path[clean.len] == '/') return true;
        }
        return false;
    }
};

pub const DeclaredMap = struct {
    suites: std.ArrayList(SuiteInputs) = .empty,

    pub fn deinit(self: *DeclaredMap, gpa: std.mem.Allocator) void {
        for (self.suites.items) |*s| s.deinit(gpa);
        self.suites.deinit(gpa);
    }

    fn getOrAdd(self: *DeclaredMap, gpa: std.mem.Allocator, suite_dir: []const u8) !*SuiteInputs {
        for (self.suites.items) |*s| {
            if (std.mem.eql(u8, s.suite_dir, suite_dir)) return s;
        }
        try self.suites.append(gpa, .{ .suite_dir = suite_dir });
        return &self.suites.items[self.suites.items.len - 1];
    }

    pub fn isCovered(self: *const DeclaredMap, suite_dir: []const u8, path: []const u8) bool {
        for (self.suites.items) |*s| {
            if (std.mem.eql(u8, s.suite_dir, suite_dir)) return s.covers(path);
        }
        return false;
    }
};

/// Extract the body of `fn addSuiteRuntimeInputs(...)` from `build.zig` and
/// parse every `addFileInput`, `addRunInputTree`, and `has_side_effects = true`
/// declaration per test suite directory. Slices borrow from `build_source`.
pub fn parseDeclaredInputs(gpa: std.mem.Allocator, build_source: []const u8) !DeclaredMap {
    var map: DeclaredMap = .{};
    errdefer map.deinit(gpa);

    const fn_start = std.mem.indexOf(u8, build_source, "fn addSuiteRuntimeInputs(") orelse return map;
    const body_open = std.mem.indexOfScalarPos(u8, build_source, fn_start, '{') orelse return map;

    // Walk lines inside addSuiteRuntimeInputs tracking brace depth.
    var depth: usize = 0;
    var current_suite: ?[]const u8 = null;
    var suite_depth: usize = 0;
    var pos: usize = body_open;
    while (pos < build_source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, build_source, pos, '\n') orelse build_source.len;
        const raw_line = build_source[pos..line_end];
        pos = if (line_end < build_source.len) line_end + 1 else build_source.len;

        // Strip single-line comments before inspecting code.
        const code = if (std.mem.indexOf(u8, raw_line, "//")) |c| raw_line[0..c] else raw_line;

        // Detect suite branch headers at depth 1 (inside addSuiteRuntimeInputs).
        if (depth == 1) {
            if (extractCallStringArg(code, "suiteIncludesDir(")) |dir| {
                current_suite = dir;
                suite_depth = 1;
            } else if (std.mem.indexOf(u8, code, "startsWith(u8, suite_name, \"wpt_runner-\")") != null) {
                current_suite = "tests/wpt_runner";
                suite_depth = 1;
            } else if (std.mem.indexOf(u8, code, "launch.engine.facts.tests") != null) {
                // Engine adapter test directory (tests/v8 for V8) tracks its own directory tree.
                const v8 = try map.getOrAdd(gpa, "tests/v8");
                try v8.trees.append(gpa, "tests/v8");
                current_suite = null;
            }
        }

        if (current_suite) |suite_dir| {
            if (extractCallStringArg(code, "addFileInput(b.path(")) |file_path| {
                const entry = try map.getOrAdd(gpa, suite_dir);
                try entry.files.append(gpa, file_path);
            }
            if (extractCallStringArg(code, "addRunInputTree(")) |tree_path| {
                const entry = try map.getOrAdd(gpa, suite_dir);
                try entry.trees.append(gpa, tree_path);
            }
            if (std.mem.indexOf(u8, code, "has_side_effects = true") != null) {
                const entry = try map.getOrAdd(gpa, suite_dir);
                entry.uncached = true;
            }
        }

        for (code) |ch| {
            if (ch == '{') {
                depth += 1;
            } else if (ch == '}') {
                if (depth > 0) depth -= 1;
                if (current_suite != null and depth <= suite_depth) {
                    current_suite = null;
                }
                if (depth == 0) return map;
            }
        }
    }
    return map;
}

/// Extract the last double-quoted string literal inside the call beginning with `marker`.
fn extractCallStringArg(line: []const u8, marker: []const u8) ?[]const u8 {
    const start = std.mem.indexOf(u8, line, marker) orelse return null;
    const rest = line[start + marker.len ..];
    // Find the matching string literal on this line (e.g. `suiteIncludesDir(suite_name, groups, "tests/devtools")`).
    const last_quote = std.mem.lastIndexOfScalar(u8, rest, '"') orelse return null;
    if (last_quote == 0) return null;
    const first_quote = std.mem.lastIndexOfScalar(u8, rest[0..last_quote], '"') orelse return null;
    if (first_quote + 1 >= last_quote) return null;
    return rest[first_quote + 1 .. last_quote];
}

pub const ReadSite = struct {
    line: usize,
    column: usize,
    path: []const u8,
};

pub fn isRepoPath(path: []const u8) bool {
    if (std.mem.startsWith(u8, path, "tests/wpt/")) return false;
    if (std.mem.eql(u8, path, "tests/wpt")) return false;
    for (repo_prefixes) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

/// Map `tests/<suite>/...` to its top-level suite directory `"tests/<suite>"`.
pub fn suiteDirOf(test_file_path: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, test_file_path, "tests/")) return null;
    const rest = test_file_path["tests/".len..];
    const slash = std.mem.indexOfScalar(u8, rest, '/') orelse return null;
    return test_file_path[0 .. "tests/".len + slash];
}

fn unquoteSimpleString(raw: []const u8) ?[]const u8 {
    if (raw.len < 2 or raw[0] != '"' or raw[raw.len - 1] != '"') return null;
    return raw[1 .. raw.len - 1];
}

fn resolvePathExpr(tree: *const Ast, expr: Ast.Node.Index, consts: *const std.StringHashMapUnmanaged([]const u8)) ?[]const u8 {
    switch (tree.nodeTag(expr)) {
        .string_literal => return unquoteSimpleString(tree.tokenSlice(tree.nodeMainToken(expr))),
        .identifier => {
            const name = tree.tokenSlice(tree.nodeMainToken(expr));
            return consts.get(name);
        },
        .array_cat => {
            // `"dir/prefix/" ++ rest` -> check the static prefix.
            const lhs = tree.nodeData(expr).node_and_node[0];
            return resolvePathExpr(tree, lhs, consts);
        },
        else => return null,
    }
}

/// Find every `readFileAlloc` call in `source` whose path argument resolves to
/// a checked-in repository path (excluding `tests/wpt/`).
pub fn findReadSites(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList(ReadSite) {
    var tree = try Ast.parse(gpa, source, .{ .mode = .zig });
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return error.ParseError;

    // Collect `const name = "literal"` bindings so helper constants resolve.
    var consts: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer consts.deinit(gpa);

    const node_count: u32 = @intCast(tree.nodes.len);
    for (1..node_count) |raw_idx| {
        const node: Ast.Node.Index = @fromBackingInt(@intCast(raw_idx));
        const vd = tree.fullVarDecl(node) orelse continue;
        const init_node = vd.ast.init_node.unwrap() orelse continue;
        if (tree.nodeTag(init_node) != .string_literal) continue;
        const val = unquoteSimpleString(tree.tokenSlice(tree.nodeMainToken(init_node))) orelse continue;
        const name_tok = vd.ast.mut_token + 1;
        if (name_tok >= tree.tokens.len) continue;
        const name = tree.tokenSlice(name_tok);
        try consts.put(gpa, name, val);
    }

    var sites: std.ArrayList(ReadSite) = .empty;
    errdefer sites.deinit(gpa);

    var call_buf: [1]Ast.Node.Index = undefined;
    for (1..node_count) |raw_idx| {
        const node: Ast.Node.Index = @fromBackingInt(@intCast(raw_idx));
        const call = tree.fullCall(&call_buf, node) orelse continue;
        if (call.ast.params.len < 2) continue;

        const fn_expr = call.ast.fn_expr;
        if (tree.nodeTag(fn_expr) != .field_access) continue;
        const field_tok = tree.nodeData(fn_expr).node_and_token[1];
        if (!std.mem.eql(u8, tree.tokenSlice(field_tok), "readFileAlloc")) continue;

        // `dir.readFileAlloc(io, sub_path, allocator, limit)` -> sub_path is params[1].
        const path = resolvePathExpr(&tree, call.ast.params[1], &consts) orelse continue;
        if (!isRepoPath(path)) continue;

        const loc = tree.tokenLocation(0, field_tok);
        try sites.append(gpa, .{
            .line = loc.line + 1,
            .column = loc.column + 1,
            .path = path,
        });
    }
    return sites;
}

pub fn isScannedTestFile(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    if (!std.mem.startsWith(u8, path, "tests/")) return false;
    if (std.mem.startsWith(u8, path, "tests/wpt/")) return false;
    if (std.mem.startsWith(u8, path, "tests/test_runner/")) return false;
    return true;
}

fn pathExistsInRepo(io: std.Io, dir: std.Io.Dir, path: []const u8) bool {
    const clean = std.mem.trimEnd(u8, path, "/");
    dir.access(io, clean, .{}) catch return false;
    return true;
}

pub fn check(io: std.Io, gpa: std.mem.Allocator, dir: std.Io.Dir, out: *std.Io.Writer) !usize {
    const build_src = try dir.readFileAlloc(io, "build.zig", gpa, .limited(64 << 20));
    defer gpa.free(build_src);

    var declared = try parseDeclaredInputs(gpa, build_src);
    defer declared.deinit(gpa);

    var tests_dir = dir.openDir(io, "tests", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    defer tests_dir.close(io);

    var violations: usize = 0;
    var walker = try tests_dir.walk(gpa);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const rel = try std.fmt.allocPrint(gpa, "tests/{s}", .{entry.path});
        defer gpa.free(rel);
        std.mem.replaceScalar(u8, rel, '\\', '/');
        if (!isScannedTestFile(rel)) continue;

        const suite_dir = suiteDirOf(rel) orelse continue;
        const source = try dir.readFileAllocOptions(io, rel, gpa, .limited(64 << 20), .of(u8), 0);
        defer gpa.free(source);

        var sites = try findReadSites(gpa, source);
        defer sites.deinit(gpa);
        for (sites.items) |site| {
            // Skip negative-test paths that do not exist in the repo (e.g. FileNotFound tests).
            if (!pathExistsInRepo(io, dir, site.path)) continue;
            if (!declared.isCovered(suite_dir, site.path)) {
                violations += 1;
                try out.print(
                    "{s}:{d}:{d}: error: readFileAlloc(\"{s}\") is not declared for suite {s} in build.zig addSuiteRuntimeInputs\n",
                    .{ rel, site.line, site.column, site.path, suite_dir },
                );
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
        try out.print("\nlint-test-inputs: {d} undeclared runtime file read(s) in tests/ (add to build.zig addSuiteRuntimeInputs).\n", .{violations});
        try out.flush();
        std.process.exit(1);
    }
    try out.print("lint-test-inputs: 0 undeclared runtime file reads in tests/.\n", .{});
}

// ============================================================================
// Tests (red and green fixtures)
// ============================================================================

const testing = std.testing;

test "findReadSites detects direct literals, const bindings, and prefix concatenations" {
    const src: [:0]const u8 =
        \\const std = @import("std");
        \\const fixture_path = "tools/mcp_diff/fixtures/sample.heapsnapshot";
        \\fn run(io: std.Io, a: std.mem.Allocator) !void {
        \\    _ = try std.Io.Dir.cwd().readFileAlloc(io, "specs/w3c/webdriver2.md", a, .unlimited);
        \\    _ = try std.Io.Dir.cwd().readFileAlloc(io, fixture_path, a, .unlimited);
        \\    _ = try std.Io.Dir.cwd().readFileAlloc(io, "tests/platform/fixtures/" ++ "x.bmp", a, .unlimited);
        \\    _ = try std.Io.Dir.cwd().readFileAlloc(io, "tests/wpt/fonts/Ahem.ttf", a, .unlimited);
        \\    _ = try std.Io.Dir.cwd().readFileAlloc(io, "/tmp/scratch.txt", a, .unlimited);
        \\}
    ;
    var sites = try findReadSites(testing.allocator, src);
    defer sites.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), sites.items.len);
    try testing.expectEqualStrings("specs/w3c/webdriver2.md", sites.items[0].path);
    try testing.expectEqualStrings("tools/mcp_diff/fixtures/sample.heapsnapshot", sites.items[1].path);
    try testing.expectEqualStrings("tests/platform/fixtures/", sites.items[2].path);
}

test "parseDeclaredInputs parses addFileInput, addRunInputTree, wpt_runner, and has_side_effects" {
    const sample_build =
        \\fn addSuiteRuntimeInputs(b: *std.Build, run: *std.Build.Step.Run, launch: *const TestLaunch, suite_name: []const u8, groups: []const SuiteGroup) void {
        \\    if (std.mem.startsWith(u8, suite_name, "wpt_runner-")) {
        \\        run.addFileInput(b.path("tests/wpt_0_1_worklist.txt"));
        \\        run.addFileInput(b.path("tools/wpt_handle_leaks_baseline.txt"));
        \\    }
        \\    if (suiteIncludesDir(suite_name, groups, "tests/devtools")) {
        \\        addRunInputTree(b, run, launch.inputs, "tests/devtools/fixtures");
        \\    }
        \\    if (suiteIncludesDir(suite_name, groups, "tests/infra")) {
        \\        run.has_side_effects = true;
        \\    }
        \\}
    ;
    var map = try parseDeclaredInputs(testing.allocator, sample_build);
    defer map.deinit(testing.allocator);

    try testing.expect(map.isCovered("tests/wpt_runner", "tests/wpt_0_1_worklist.txt"));
    try testing.expect(map.isCovered("tests/wpt_runner", "tools/wpt_handle_leaks_baseline.txt"));
    try testing.expect(!map.isCovered("tests/wpt_runner", "tools/other.txt"));

    try testing.expect(map.isCovered("tests/devtools", "tests/devtools/fixtures/trace.txt"));
    try testing.expect(!map.isCovered("tests/devtools", "tools/mcp_diff/fixtures/sample.heapsnapshot"));

    try testing.expect(map.isCovered("tests/infra", "src/anything/file.zig"));
}

test "check flags undeclared repo readFileAlloc and allows declared, wpt submodule, and nonexistent paths" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;

    try tmp.dir.createDirPath(io, "tests/devtools/fixtures");
    try tmp.dir.createDirPath(io, "tools/mcp_diff/fixtures");
    try tmp.dir.writeFile(io, .{ .sub_path = "tests/devtools/fixtures/ok.txt", .data = "ok" });
    try tmp.dir.writeFile(io, .{ .sub_path = "tools/mcp_diff/fixtures/sample.heapsnapshot", .data = "{}" });
    try tmp.dir.writeFile(io, .{
        .sub_path = "build.zig",
        .data =
        \\fn addSuiteRuntimeInputs(b: *std.Build, run: *std.Build.Step.Run, launch: *const TestLaunch, suite_name: []const u8, groups: []const SuiteGroup) void {
        \\    if (suiteIncludesDir(suite_name, groups, "tests/devtools")) {
        \\        addRunInputTree(b, run, launch.inputs, "tests/devtools/fixtures");
        \\    }
        \\}
        ,
    });
    try tmp.dir.writeFile(io, .{
        .sub_path = "tests/devtools/sample_test.zig",
        .data =
        \\const std = @import("std");
        \\fn f(io: std.Io, a: std.mem.Allocator) !void {
        \\    _ = try std.Io.Dir.cwd().readFileAlloc(io, "tests/devtools/fixtures/ok.txt", a, .unlimited);
        \\    _ = try std.Io.Dir.cwd().readFileAlloc(io, "tools/mcp_diff/fixtures/sample.heapsnapshot", a, .unlimited);
        \\    _ = try std.Io.Dir.cwd().readFileAlloc(io, "tests/devtools/does-not-exist.txt", a, .unlimited);
        \\}
        ,
    });

    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    const count = try check(io, testing.allocator, tmp.dir, &w);
    try testing.expectEqual(@as(usize, 1), count);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "tools/mcp_diff/fixtures/sample.heapsnapshot") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "ok.txt") == null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "does-not-exist.txt") == null);
}
