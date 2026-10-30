//! The Zig 0.17 `@hasDecl` audit (roadmap zig-017; lane zig017trial).
//!
//! Zig 0.16 answers `@hasDecl(T, "x")` true when T declares `x` and EITHER `x` is `pub` OR the
//! `@hasDecl` is in the file that declares `x`. Zig 0.17 answers true only for `pub`: "the
//! behavior is the same independently of which file `@hasDecl` is in" (0.17.0 release notes).
//! Nothing fails to compile - a same-file `@hasDecl` on a non-pub declaration silently turns
//! false - and the binding finds impl functions by name.
//!
//! So an answer can change only where a file asks about a non-pub declaration THE SAME FILE
//! declares: a non-pub declaration of another file was invisible to `@hasDecl` already. This tool
//! reads every `@hasDecl` in src/, tests/, tools/ and build.zig through std.zig.Ast and gives each
//! a verdict:
//!
//! - `unchanged`: the file declares no non-pub declaration the name can be (sound by the rule
//!   above), or the target resolves to another file (`@import`), or to containers of this file
//!   none of which declares the name non-pub;
//! - `changes`: the target resolves to containers of this file that all declare the name non-pub;
//! - `possible`: the file declares a non-pub declaration the name can be, and the target or the
//!   name is computed (a parameter, a generic result, `"call_" ++ name`) so the text cannot say;
//! - `known`: a `changes` or `possible` site of a measured flip left for the port window
//!   (`known_flips`: its file is held by another lane or row).
//!
//! The text decides `changes` and `unchanged` exactly; `possible` needs a compiler. So
//! `--instrument=<dir>` writes a copy of every file with a `changes` or `possible` site in which
//! each such `@hasDecl(T, n)` also asks the pub-only question (`std.meta.declarations` lists pub
//! declarations only) and `@compileLog`s `HASDECL-FLIP <path>:<line>` with T and n where the two
//! answers differ. Overlay the copies on a scratch checkout and build it with Zig 0.16: the logs
//! are exactly the `@hasDecl` evaluations, per instantiation, whose answer 0.17 changes.
//!
//!     zig build hasdecl-audit                      # summary and every changes/possible site
//!     zig build hasdecl-audit -- --all             # also per-file counts of every site
//!     zig build hasdecl-audit -- --instrument=<dir>
//!
//! Assumption: a file never `@import`s itself (an `@import` target counts as another file).

const std = @import("std");
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;

pub const Verdict = enum { unchanged, changes, possible, known };

/// A flip measured and left for the Zig 0.17 port window because another lane or row holds its
/// file: `main` reports a `changes` or `possible` site matching one as `known`, and counts it
/// apart (lane zigprep1, 2026-10-29). Each is a RED-first test guard; the fix is `pub` on the
/// declaration (the same answer on 0.16). Delete an entry with its fix.
pub const KnownFlip = struct { path: []const u8, name: []const u8 };

pub const known_flips = [_]KnownFlip{
    // src/css/cascade.zig: cv1HasSourceApi (8 tests) and the CandidateIndex guard (1 test); row 127.
    .{ .path = "src/css/cascade.zig", .name = "\"collectCandidates\"" },
    .{ .path = "src/css/cascade.zig", .name = "\"CandidateIndex\"" },
    // src/dom/style/engine.zig: the treeCounts guard (1 test); rows 127/128, lane rendering3.
    .{ .path = "src/dom/style/engine.zig", .name = "\"treeCounts\"" },
};

/// The verdict `main` reports: a flagged site that matches a known flip is `known`.
pub fn reported(path: []const u8, site: Site) Verdict {
    if (site.verdict == .unchanged) return .unchanged;
    for (known_flips) |flip| {
        if (std.mem.eql(u8, flip.path, path) and std.mem.eql(u8, flip.name, site.name)) return .known;
    }
    return site.verdict;
}

pub const Site = struct {
    line: u32,
    /// The byte span of the whole `@hasDecl(...)` call.
    start: u32,
    end: u32,
    target: []const u8,
    name: []const u8,
    verdict: Verdict,
    why: []const u8,
};

pub const FileAudit = struct {
    sites: []const Site,
    /// Non-pub declarations (const, var, fn) in any container of the file.
    nonpub_count: usize,
};

const Container = struct {
    start: u32,
    end: u32,
    /// What the report calls it: `(file)`, the name it is bound to, or `struct@<line>`.
    label: []const u8,
    nonpub: std.StringHashMapUnmanaged(void) = .empty,
    /// Member declarations by name: the init node, for `A.B` resolution.
    members: std.StringHashMapUnmanaged(Ast.Node.Index) = .empty,
    member_offsets: std.StringHashMapUnmanaged(u32) = .empty,
};

const Binding = struct {
    init: Ast.Node.Index,
    /// Where the declaration starts: `@This()` in its init means the container around here.
    offset: u32,
};

const Outcome = union(enum) {
    local: usize,
    cross_file,
    unknown,
};

const Audit = struct {
    arena: Allocator,
    tree: *const Ast,
    containers: std.ArrayList(Container) = .empty,
    /// Spans of every container and block: the scopes a binding can be visible in.
    scopes: std.ArrayList([2]u32) = .empty,
    bindings: std.StringHashMapUnmanaged(std.ArrayList(Binding)) = .empty,
    nonpub_all: std.StringHashMapUnmanaged(void) = .empty,

    fn span(a: *const Audit, node: Ast.Node.Index) [2]u32 {
        const first = a.tree.firstToken(node);
        const last = a.tree.lastToken(node);
        return .{ a.tree.tokenStart(first), @intCast(a.tree.tokenStart(last) + a.tree.tokenSlice(last).len) };
    }

    fn text(a: *const Audit, node: Ast.Node.Index) []const u8 {
        const s = a.span(node);
        return a.tree.source[s[0]..s[1]];
    }

    fn lineOf(a: *const Audit, offset: u32) u32 {
        return @intCast(std.mem.count(u8, a.tree.source[0..offset], "\n") + 1);
    }

    /// The innermost container whose span holds `offset`.
    fn containerAt(a: *const Audit, offset: u32) usize {
        var best: usize = 0;
        for (a.containers.items, 0..) |c, i| {
            if (c.start <= offset and offset < c.end and c.end - c.start <= a.containers.items[best].end - a.containers.items[best].start) best = i;
        }
        return best;
    }

    /// The innermost scope (container or block) holding `offset`, as its span.
    fn scopeAt(a: *const Audit, offset: u32) [2]u32 {
        var best: [2]u32 = .{ 0, @intCast(a.tree.source.len) };
        for (a.scopes.items) |s| {
            if (s[0] <= offset and offset < s[1] and s[1] - s[0] < best[1] - best[0]) best = s;
        }
        return best;
    }

    fn collect(a: *Audit) !void {
        const tree = a.tree;
        try a.containers.append(a.arena, .{ .start = 0, .end = @intCast(tree.source.len), .label = "(file)" });
        try a.addMembers(0, tree.rootDecls());
        for (0..tree.nodes.len) |i| {
            const node: Ast.Node.Index = @enumFromInt(i);
            switch (tree.nodeTag(node)) {
                .root => {},
                .block, .block_semicolon, .block_two, .block_two_semicolon => try a.scopes.append(a.arena, a.span(node)),
                else => {
                    var buf: [2]Ast.Node.Index = undefined;
                    const decl = tree.fullContainerDecl(&buf, node) orelse continue;
                    const s = a.span(node);
                    try a.scopes.append(a.arena, s);
                    const index = a.containers.items.len;
                    try a.containers.append(a.arena, .{
                        .start = s[0],
                        .end = s[1],
                        .label = try std.fmt.allocPrint(a.arena, "{s}@{d}", .{ tree.tokenSlice(decl.ast.main_token), a.lineOf(s[0]) }),
                    });
                    try a.addMembers(index, decl.ast.members);
                },
            }
        }
        // Every variable declaration, member or local, by name; and container labels.
        for (0..tree.nodes.len) |i| {
            const node: Ast.Node.Index = @enumFromInt(i);
            const var_decl = tree.fullVarDecl(node) orelse continue;
            const init = var_decl.ast.init_node.unwrap() orelse continue;
            const name = tree.tokenSlice(var_decl.ast.mut_token + 1);
            const gop = try a.bindings.getOrPut(a.arena, name);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(a.arena, .{ .init = init, .offset = a.span(node)[0] });
            var buf: [2]Ast.Node.Index = undefined;
            if (tree.fullContainerDecl(&buf, init) != null) {
                const s = a.span(init);
                for (a.containers.items) |*c| if (c.start == s[0] and c.end == s[1]) {
                    c.label = name;
                };
            }
        }
    }

    fn addMembers(a: *Audit, index: usize, members: []const Ast.Node.Index) !void {
        const tree = a.tree;
        for (members) |member| {
            var name: []const u8 = undefined;
            var is_pub = false;
            var init: ?Ast.Node.Index = null;
            if (tree.fullVarDecl(member)) |var_decl| {
                name = tree.tokenSlice(var_decl.ast.mut_token + 1);
                is_pub = var_decl.visib_token != null;
                init = var_decl.ast.init_node.unwrap();
            } else {
                var buf: [1]Ast.Node.Index = undefined;
                const proto_node = if (tree.nodeTag(member) == .fn_decl) tree.nodeData(member).node_and_node[0] else member;
                const proto = tree.fullFnProto(&buf, proto_node) orelse continue;
                name = tree.tokenSlice(proto.name_token orelse continue);
                is_pub = proto.visib_token != null;
            }
            if (name.len > 1 and name[0] == '@') {
                name = std.zig.string_literal.parseAlloc(a.arena, name[1..]) catch continue;
            }
            const c = &a.containers.items[index];
            if (!is_pub) {
                try c.nonpub.put(a.arena, name, {});
                try a.nonpub_all.put(a.arena, name, {});
            }
            if (init) |node| {
                try c.members.put(a.arena, name, node);
                try c.member_offsets.put(a.arena, name, a.span(member)[0]);
            }
        }
    }

    /// What the type expression `node`, read at `offset`, refers to.
    fn resolve(a: *const Audit, node: Ast.Node.Index, offset: u32, depth: u8) Outcome {
        if (depth > 16) return .unknown;
        const tree = a.tree;
        switch (tree.nodeTag(node)) {
            .builtin_call_two, .builtin_call_two_comma, .builtin_call, .builtin_call_comma => {
                const builtin = tree.tokenSlice(tree.nodeMainToken(node));
                if (std.mem.eql(u8, builtin, "@This")) return .{ .local = a.containerAt(offset) };
                if (std.mem.eql(u8, builtin, "@import")) return .cross_file;
                return .unknown;
            },
            .identifier => {
                const name = tree.tokenSlice(tree.nodeMainToken(node));
                const list = a.bindings.get(name) orelse return .unknown;
                var best: ?Binding = null;
                var best_size: u32 = std.math.maxInt(u32);
                for (list.items) |b| {
                    const scope = a.scopeAt(b.offset);
                    if (scope[0] <= offset and offset < scope[1] and scope[1] - scope[0] < best_size) {
                        best = b;
                        best_size = scope[1] - scope[0];
                    }
                }
                const b = best orelse return .unknown;
                return a.resolve(b.init, b.offset, depth + 1);
            },
            .field_access => {
                const lhs, const field = tree.nodeData(node).node_and_token;
                switch (a.resolve(lhs, offset, depth + 1)) {
                    .cross_file => return .cross_file,
                    .unknown => return .unknown,
                    .local => |c| {
                        const container = &a.containers.items[c];
                        const member = container.members.get(tree.tokenSlice(field)) orelse return .unknown;
                        return a.resolve(member, container.member_offsets.get(tree.tokenSlice(field)).?, depth + 1);
                    },
                }
            },
            .grouped_expression => return a.resolve(tree.nodeData(node).node_and_token[0], offset, depth + 1),
            else => {
                var buf: [2]Ast.Node.Index = undefined;
                if (tree.fullContainerDecl(&buf, node) != null) {
                    const s = a.span(node);
                    for (a.containers.items, 0..) |c, i| if (c.start == s[0] and c.end == s[1]) return .{ .local = i };
                }
                return .unknown;
            },
        }
    }

    const Pattern = struct { exact: ?[]const u8, prefix: []const u8, suffix: []const u8 };

    /// The name argument: a literal, or the literal ends of a `++` chain.
    fn pattern(a: *const Audit, node: Ast.Node.Index) Pattern {
        const tree = a.tree;
        if (tree.nodeTag(node) == .string_literal) {
            const bytes = std.zig.string_literal.parseAlloc(a.arena, tree.tokenSlice(tree.nodeMainToken(node))) catch
                return .{ .exact = null, .prefix = "", .suffix = "" };
            return .{ .exact = bytes, .prefix = "", .suffix = "" };
        }
        if (tree.nodeTag(node) == .array_cat) {
            var left = node;
            while (tree.nodeTag(left) == .array_cat) left = tree.nodeData(left).node_and_node[0];
            var right = node;
            while (tree.nodeTag(right) == .array_cat) right = tree.nodeData(right).node_and_node[1];
            const prefix = a.pattern(left);
            const suffix = a.pattern(right);
            return .{ .exact = null, .prefix = prefix.exact orelse "", .suffix = suffix.exact orelse "" };
        }
        return .{ .exact = null, .prefix = "", .suffix = "" };
    }

    fn matches(p: Pattern, name: []const u8) bool {
        if (p.exact) |e| return std.mem.eql(u8, e, name);
        return name.len >= p.prefix.len + p.suffix.len and std.mem.startsWith(u8, name, p.prefix) and std.mem.endsWith(u8, name, p.suffix);
    }

    fn anyMatch(set: *const std.StringHashMapUnmanaged(void), p: Pattern) bool {
        if (p.exact) |e| return set.contains(e);
        var it = set.keyIterator();
        while (it.next()) |k| if (matches(p, k.*)) return true;
        return false;
    }

    fn judge(a: *const Audit, target: Ast.Node.Index, name: Ast.Node.Index, offset: u32) struct { Verdict, []const u8 } {
        const p = a.pattern(name);
        if (!anyMatch(&a.nonpub_all, p)) return .{ .unchanged, "no non-pub declaration of that name in this file" };
        switch (a.resolve(target, offset, 0)) {
            .cross_file => return .{ .unchanged, "the target is another file's" },
            .unknown => return .{ .possible, if (p.exact != null) "target unresolved; this file declares that name non-pub" else "name and target computed; this file declares a matching name non-pub" },
            .local => |c| {
                const container = &a.containers.items[c];
                if (!anyMatch(&container.nonpub, p)) return .{ .unchanged, "the target, in this file, declares no such name non-pub" };
                if (p.exact != null) return .{ .changes, std.fmt.allocPrint(a.arena, "non-pub in {s}: 0.16 true, 0.17 false", .{container.label}) catch "non-pub in this file" };
                return .{ .possible, std.fmt.allocPrint(a.arena, "computed name; {s} declares a matching name non-pub", .{container.label}) catch "computed name" };
            },
        }
    }
};

/// Audits one file's source. Allocations are the caller's (an arena).
pub fn auditSource(arena: Allocator, source: [:0]const u8) !FileAudit {
    var tree = try Ast.parse(arena, source, .zig);
    if (tree.errors.len > 0) return error.ParseError;
    var a: Audit = .{ .arena = arena, .tree = &tree };
    try a.collect();
    var sites: std.ArrayList(Site) = .empty;
    for (0..tree.nodes.len) |i| {
        const node: Ast.Node.Index = @enumFromInt(i);
        switch (tree.nodeTag(node)) {
            .builtin_call_two, .builtin_call_two_comma, .builtin_call, .builtin_call_comma => {},
            else => continue,
        }
        if (!std.mem.eql(u8, tree.tokenSlice(tree.nodeMainToken(node)), "@hasDecl")) continue;
        var buf: [2]Ast.Node.Index = undefined;
        const params = tree.builtinCallParams(&buf, node) orelse continue;
        if (params.len != 2) continue;
        const s = a.span(node);
        const verdict, const why = a.judge(params[0], params[1], s[0]);
        try sites.append(arena, .{
            .line = a.lineOf(s[0]),
            .start = s[0],
            .end = s[1],
            .target = a.text(params[0]),
            .name = a.text(params[1]),
            .verdict = verdict,
            .why = why,
        });
    }
    std.mem.sort(Site, sites.items, {}, struct {
        fn lt(_: void, x: Site, y: Site) bool {
            return x.start < y.start;
        }
    }.lt);
    return .{ .sites = sites.items, .nonpub_count = a.nonpub_all.count() };
}

/// `source` with every `changes`/`possible` site wrapped in the flip probe, and the probe's
/// helper appended. Null when the file has no such site.
pub fn instrument(arena: Allocator, path: []const u8, source: []const u8, audit: FileAudit) !?[]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var at: usize = 0;
    var any = false;
    for (audit.sites) |site| {
        if (site.verdict == .unchanged) continue;
        any = true;
        try out.appendSlice(arena, source[at..site.start]);
        try out.print(arena,
            \\(hasdecl_audit_probe: {{ const hasdecl_audit_r = @hasDecl({s}, {s}); if (hasdecl_audit_r != hasdeclAuditPubOnly({s}, {s})) @compileLog("HASDECL-FLIP {s}:{d}", @typeName({s}), {s}); break :hasdecl_audit_probe hasdecl_audit_r; }})
        , .{ site.target, site.name, site.target, site.name, path, site.line, site.target, site.name });
        at = site.end;
    }
    if (!any) return null;
    try out.appendSlice(arena, source[at..]);
    try out.appendSlice(arena,
        \\
        \\/// hasdecl_audit: the pub-only answer (std.meta.declarations lists pub declarations only).
        \\inline fn hasdeclAuditPubOnly(comptime T: type, comptime n: []const u8) bool {
        \\    return comptime hasdecl_audit_pub: {
        \\        @setEvalBranchQuota(1_000_000);
        \\        for (@import("std").meta.declarations(T)) |d| {
        \\            if (@import("std").mem.eql(u8, d.name, n)) break :hasdecl_audit_pub true;
        \\        }
        \\        break :hasdecl_audit_pub false;
        \\    };
        \\}
        \\
    );
    return out.items;
}

const scanned_roots = [_][]const u8{ "src", "tests", "tools" };
/// Not built (codegen's stubs), or not ours.
const skipped = [_][]const u8{ "src/webidl/impls_tmp/", "tests/wpt/", ".zig-cache/", "zig-pkg/" };

fn isScanned(path: []const u8) bool {
    if (!std.mem.endsWith(u8, path, ".zig")) return false;
    for (skipped) |prefix| if (std.mem.indexOf(u8, path, prefix) != null) return false;
    return true;
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var all = false;
    var instrument_dir: ?[]const u8 = null;
    var args = try init.minimal.args.iterateAllocator(arena);
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--all")) {
            all = true;
        } else if (std.mem.startsWith(u8, arg, "--instrument=")) {
            instrument_dir = arg["--instrument=".len..];
        } else {
            std.debug.print("usage: hasdecl_audit [--all] [--instrument=<dir>]\n", .{});
            std.process.exit(2);
        }
    }

    var paths: std.ArrayList([]const u8) = .empty;
    try paths.append(arena, "build.zig");
    for (scanned_roots) |root| {
        var dir = std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer dir.close(io);
        var walker = try dir.walk(arena);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind != .file) continue;
            const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ root, entry.path });
            std.mem.replaceScalar(u8, path, '\\', '/');
            if (isScanned(path)) try paths.append(arena, path);
        }
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn lt(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.order(u8, x, y) == .lt;
        }
    }.lt);

    var stdout_buf: [8192]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    var totals = std.EnumArray(Verdict, usize).initFill(0);
    var files_with_sites: usize = 0;
    var files_flagged: usize = 0;
    var written: usize = 0;
    for (paths.items) |path| {
        const source = std.Io.Dir.cwd().readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        const audit = auditSource(arena, source) catch |err| switch (err) {
            error.ParseError => {
                try out.print("PARSE-ERROR {s}\n", .{path});
                continue;
            },
            else => return err,
        };
        if (audit.sites.len == 0) continue;
        files_with_sites += 1;
        const sites = try arena.dupe(Site, audit.sites);
        for (sites) |*site| site.verdict = reported(path, site.*);
        var counts = std.EnumArray(Verdict, usize).initFill(0);
        for (sites) |site| counts.getPtr(site.verdict).* += 1;
        for (std.enums.values(Verdict)) |v| totals.getPtr(v).* += counts.get(v);
        const flagged = counts.get(.changes) + counts.get(.possible);
        if (flagged > 0) files_flagged += 1;
        if (all or flagged > 0 or counts.get(.known) > 0) {
            try out.print("FILE {s}: {d} @hasDecl, {d} changes, {d} possible, {d} known, {d} non-pub declarations\n", .{ path, sites.len, counts.get(.changes), counts.get(.possible), counts.get(.known), audit.nonpub_count });
        }
        for (sites) |site| {
            if (site.verdict == .unchanged and !all) continue;
            try out.print("  {s} {s}:{d} @hasDecl({s}, {s}) - {s}\n", .{ @tagName(site.verdict), path, site.line, site.target, site.name, site.why });
        }
        if (instrument_dir) |dir| if (try instrument(arena, path, source, audit)) |text| {
            const dest = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, path });
            if (std.fs.path.dirname(dest)) |parent| try std.Io.Dir.cwd().createDirPath(io, parent);
            try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = dest, .data = text });
            written += 1;
        };
    }
    try out.print("TOTAL {d} @hasDecl in {d} files: {d} unchanged, {d} changes, {d} possible, {d} known ({d} files with changes or possible)\n", .{
        totals.get(.unchanged) + totals.get(.changes) + totals.get(.possible) + totals.get(.known), files_with_sites, totals.get(.unchanged), totals.get(.changes), totals.get(.possible), totals.get(.known), files_flagged,
    });
    if (instrument_dir) |dir| try out.print("INSTRUMENTED {d} files into {s}\n", .{ written, dir });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn auditFor(arena: Allocator, comptime source: [:0]const u8) !FileAudit {
    return auditSource(arena, source);
}

fn expectVerdicts(comptime source: [:0]const u8, expected: []const Verdict) !void {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const audit = try auditFor(arena_state.allocator(), source);
    try testing.expectEqual(expected.len, audit.sites.len);
    for (expected, audit.sites) |want, site| {
        testing.expectEqual(want, site.verdict) catch |err| {
            std.debug.print("site {d} @hasDecl({s}, {s}): {s}\n", .{ site.line, site.target, site.name, site.why });
            return err;
        };
    }
}

test "a same-file non-pub declaration changes; a pub one does not" {
    try expectVerdicts(
        \\const A = struct { const hidden = 1; pub const shown = 2; };
        \\const x = @hasDecl(A, "hidden");
        \\const y = @hasDecl(A, "shown");
    , &.{ .changes, .unchanged });
}

test "the default is unchanged only when no non-pub declaration has the name" {
    // T is a parameter: unresolved. With no non-pub `deinit` anywhere in the file the answer
    // cannot change; with one, it may.
    try expectVerdicts(
        \\fn f(comptime T: type) bool { return @hasDecl(T, "deinit"); }
    , &.{.unchanged});
    try expectVerdicts(
        \\fn f(comptime T: type) bool { return @hasDecl(T, "deinit"); }
        \\const S = struct { fn deinit() void {} };
    , &.{.possible});
}

test "a target in another file is unchanged, even when this file has the name non-pub" {
    try expectVerdicts(
        \\const impls = @import("impls");
        \\const XImpl = impls.XImpl;
        \\fn call_foo() void {}
        \\const a = @hasDecl(XImpl, "call_foo");
        \\const b = @hasDecl(@import("other.zig"), "call_foo");
    , &.{ .unchanged, .unchanged });
}

test "@This() and Self resolve to the enclosing container" {
    try expectVerdicts(
        \\const A = struct {
        \\    const Self = @This();
        \\    fn helper() void {}
        \\    const has = @hasDecl(Self, "helper");
        \\    const has2 = @hasDecl(@This(), "helper");
        \\};
        \\const B = struct {
        \\    const Self = @This();
        \\    pub fn helper() void {}
        \\    const has = @hasDecl(Self, "helper");
        \\};
    , &.{ .changes, .changes, .unchanged });
}

test "a nested container is reached through its parent" {
    try expectVerdicts(
        \\const Outer = struct { const Inner = struct { const secret = 1; }; };
        \\const a = @hasDecl(Outer.Inner, "secret");
        \\const b = @hasDecl(Outer, "secret");
    , &.{ .changes, .unchanged });
}

test "a computed name is possible only where a non-pub name matches its literal ends" {
    try expectVerdicts(
        \\fn get(comptime T: type, comptime member: []const u8) bool { return @hasDecl(T, "call_" ++ member); }
        \\fn call_private() void {}
    , &.{.possible});
    try expectVerdicts(
        \\fn get(comptime T: type, comptime member: []const u8) bool { return @hasDecl(T, "call_" ++ member); }
        \\fn helper() void {}
    , &.{.unchanged});
}

test "a pub-only file never changes" {
    try expectVerdicts(
        \\pub fn deinit() void {}
        \\pub const Self = @This();
        \\pub fn f(comptime T: type) bool { return @hasDecl(T, "deinit") and @hasDecl(Self, "deinit"); }
    , &.{ .unchanged, .unchanged });
}

test "a flagged site of a known flip is reported known; nothing else is" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const source =
        \\const Self = @This();
        \\fn treeCounts() void {}
        \\fn other() void {}
        \\const a = @hasDecl(Self, "treeCounts");
        \\const b = @hasDecl(Self, "other");
        \\
    ;
    const audit = try auditSource(arena, source);
    try testing.expectEqual(Verdict.changes, audit.sites[0].verdict);
    try testing.expectEqual(Verdict.known, reported("src/dom/style/engine.zig", audit.sites[0]));
    // The same name in another file, and another name in the known file, stay as audited.
    try testing.expectEqual(Verdict.changes, reported("src/dom/other.zig", audit.sites[0]));
    try testing.expectEqual(Verdict.changes, reported("src/dom/style/engine.zig", audit.sites[1]));
    // An unchanged site is never known.
    const clean = "pub fn treeCounts() void {}\nconst a = @hasDecl(@This(), \"treeCounts\");\n";
    const clean_audit = try auditSource(arena, clean);
    try testing.expectEqual(Verdict.unchanged, reported("src/dom/style/engine.zig", clean_audit.sites[0]));
}

test "instrument wraps only flagged sites and appends the helper once" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const source =
        \\const A = struct { const hidden = 1; pub const shown = 2; };
        \\const x = @hasDecl(A, "hidden");
        \\const y = @hasDecl(A, "shown");
        \\
    ;
    const audit = try auditSource(arena, source);
    const text = (try instrument(arena, "src/a.zig", source, audit)).?;
    try testing.expect(std.mem.indexOf(u8, text, "@compileLog(\"HASDECL-FLIP src/a.zig:2\"") != null);
    try testing.expect(std.mem.indexOf(u8, text, "const y = @hasDecl(A, \"shown\");") != null);
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, text, "inline fn hasdeclAuditPubOnly"));
    // A target with more than a few hundred declarations (a generated interface) must not stop
    // the probe at the default 1,000-branch quota (lane zig017trial's first measurement did).
    try testing.expect(std.mem.indexOf(u8, text, "@setEvalBranchQuota(1_000_000);") != null);
    // A file with nothing flagged is not copied.
    const clean = "pub const A = struct {};\nconst z = @hasDecl(A, \"x\");\n";
    try testing.expect((try instrument(arena, "src/b.zig", clean, try auditSource(arena, clean))) == null);
}

test "the probe compiles, and finds exactly the flips, when instrumented code is built" {
    // The probe's semantics are checked by building an instrumented tree with Zig 0.16 (the
    // HASDECL-FLIP logs); here, that it parses wherever a @hasDecl may stand.
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const source =
        \\const A = struct { const hidden = 1; };
        \\fn f(comptime T: type) bool {
        \\    if (comptime @hasDecl(T, "hidden")) return true;
        \\    return !@hasDecl(T, "hidden") and @hasDecl(A, "hidden");
        \\}
        \\
    ;
    const audit = try auditSource(arena, source);
    const text = try arena.dupeSentinel(u8, (try instrument(arena, "src/f.zig", source, audit)).?, 0);
    const tree = try Ast.parse(arena, text, .zig);
    try testing.expectEqual(@as(usize, 0), tree.errors.len);
    try testing.expectEqual(@as(usize, 3), std.mem.count(u8, text, "HASDECL-FLIP"));
}
