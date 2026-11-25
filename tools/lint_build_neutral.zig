//! The build's neutrality, a plain rule: `zig build lint-build` (and so `zig
//! build test`) fails when build.zig, or a file it imports, names an engine,
//! an operating system or a platform library at all.
//!
//! The rule (the user, 2026-11-12): no engine- or platform-specific code in
//! build.zig. An adapter declares its build options, sources and link inputs
//! in its own build file, behind the build side of its protocol
//! (src/runtime/engine_build_protocol.zig; src/platform/
//! platform_build_protocol.zig with the kit's src/platform/kit/kit_build.zig),
//! and the root build names no adapter. The migration that got there moved a
//! slice per batch (tmp/plans/build-protocol-design.md) against a baseline
//! that only went down; its last batch (P4, 2026-11-24) took it to zero, and
//! the baseline is gone: any name fails.
//!
//! What is scanned: the root (build.zig) and every `.zig` file reached from it
//! through `@import("<path>.zig")`, each held by where it lives:
//!   * a build file of the engine protocol or of an engine adapter
//!     (src/runtime/engine_build_protocol.zig, src/runtime/engines/) is where
//!     engines are named: not counted, though its imports are followed;
//!   * a build file of the platform (src/platform/) may name an operating
//!     system and its libraries, never an engine: engine keys only;
//!   * everything else - build.zig and the neutral helpers it imports - is
//!     counted for every key.
//! `test` declarations are exempt, and an import inside one is not followed.
//!
//! What is counted, per file, per key and per kind of text:
//!   * the keys come from the command line, in four classes - `--engine=`,
//!     `--platform=`, `--target=` (a branch on the target's OS) and `--library=`,
//!     each a comma-separated list. build.zig passes them, so this file names
//!     no adapter. A key matches wherever its text occurs (case ignored,
//!     except in the target class); `word:<key>` matches only a whole word or
//!     a whole part of a camelCase name (`word:ios` counts `.ios`, `iOS` and
//!     `addIosSdkPaths`, not `scenarios`); a key that is an enum literal
//!     (`.testing`) matches only as one, so not `std.testing`;
//!   * the kinds are `code`, `comment` (after `//`) and `script` (a line of a
//!     multiline string literal: an embedded shell script). Comments count as
//!     code does (the integrator's ruling, 2026-11-12): a comment that names
//!     an engine in neutral code explains engine behaviour, and belongs where
//!     that code went. A library key is not counted in a script, where `curl`
//!     is a command the script runs.
//!
//! Any occurrence fails, printed with its file, line, key and kind: move it
//! behind its protocol's build side, or say what it meant without the name.
//! `-- --list` prints every site; `-- --update` is refused - there is no
//! baseline to record - and tools/build_neutral_baseline.txt is refused if it
//! comes back (`refuseBaseline`, as lint-impls refuses its retired one).

const std = @import("std");
// stdout as a stream: Zig 0.17's positional File.writer overwrites a shared log.
const stdout_stream = @import("stdout_stream.zig");

/// The ratchet's baseline until the rule reached zero; refused if it comes
/// back (`refuseBaseline`).
const retired_baseline_path = "tools/build_neutral_baseline.txt";

/// The file the scan starts from.
const root_path = "build.zig";

/// What a key names.
pub const Class = enum {
    /// A JavaScript engine: an engine adapter's own words.
    engine,
    /// An operating system or a platform adapter.
    platform,
    /// A branch on the target's operating system.
    target,
    /// A C library the platform owns.
    library,

    /// A branch is an identifier; a name is a name in any case.
    fn ignoresCase(class: Class) bool {
        return class != .target;
    }

    /// An embedded script calls `curl` the command, not the library.
    fn countedInScripts(class: Class) bool {
        return class != .library;
    }

    fn flag(class: Class) []const u8 {
        return switch (class) {
            .engine => "--engine=",
            .platform => "--platform=",
            .target => "--target=",
            .library => "--library=",
        };
    }
};

const classes = [_]Class{ .engine, .platform, .target, .library };

/// How a key's text is matched.
pub const Match = enum {
    /// Wherever the text occurs: `v8` in `linkV8`, `libv8_monolith.a`.
    substring,
    /// A whole word, or a whole part of a camelCase name.
    word,
    /// `.name` where the dot opens an enum literal, not a member access.
    enum_literal,
};

pub const Key = struct {
    class: Class,
    /// The text matched, and the key's name in the baseline.
    text: []const u8,
    match: Match,
};

/// The kind of text an occurrence stands in.
pub const Kind = enum { code, comment, script };

/// How a file is held.
pub const Scope = enum {
    /// Where engines are named: not counted.
    none,
    /// The platform's build files: no engine there.
    engine_only,
    /// Neutral code: every key.
    all,
};

/// The scope of `path` (repo-relative, `/`-separated).
pub fn scopeOf(path: []const u8) Scope {
    if (std.mem.eql(u8, path, "src/runtime/engine_build_protocol.zig")) return .none;
    if (std.mem.eql(u8, path, "src/platform/platform_build_protocol.zig")) return .none;
    if (std.mem.startsWith(u8, path, "src/runtime/engines/")) return .none;
    if (std.mem.startsWith(u8, path, "src/platform/")) return .engine_only;
    return .all;
}

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn isIdentifier(text: []const u8) bool {
    if (text.len == 0 or std.ascii.isDigit(text[0])) return false;
    for (text) |c| if (!isIdentChar(c)) return false;
    return true;
}

/// Append the keys of `list` (`a,word:b,.c`) to `keys`. Key texts are slices
/// of `list`.
pub fn parseKeys(gpa: std.mem.Allocator, keys: *std.ArrayList(Key), class: Class, list: []const u8) !void {
    var parts = std.mem.splitScalar(u8, list, ',');
    while (parts.next()) |raw| {
        const part = std.mem.trim(u8, raw, " ");
        if (part.len == 0) continue;
        if (std.mem.startsWith(u8, part, "word:")) {
            if (part.len > "word:".len) try keys.append(gpa, .{ .class = class, .text = part["word:".len..], .match = .word });
        } else if (part[0] == '.' and isIdentifier(part[1..])) {
            try keys.append(gpa, .{ .class = class, .text = part, .match = .enum_literal });
        } else {
            try keys.append(gpa, .{ .class = class, .text = part, .match = .substring });
        }
    }
}

/// Whether `key` matches in `line` at `at`.
fn matchesAt(line: []const u8, at: usize, key: Key) bool {
    const text = key.text;
    if (at + text.len > line.len) return false;
    const found = line[at..][0..text.len];
    const same = if (key.class.ignoresCase()) std.ascii.eqlIgnoreCase(found, text) else std.mem.eql(u8, found, text);
    if (!same) return false;
    const before: u8 = if (at > 0) line[at - 1] else ' ';
    const after: u8 = if (at + text.len < line.len) line[at + text.len] else ' ';
    switch (key.match) {
        .substring => return true,
        .word => {
            // A letter beside the match is allowed only across a camelCase
            // hump: `addIosSdk` (d|I, s|S), never `scenarios` (r|i). And a
            // build option's name begins a word: `-Dios-sdk`.
            const first = found[0];
            const last = found[found.len - 1];
            const option_name = before == 'D' and at >= 2 and line[at - 2] == '-';
            const left = !std.ascii.isAlphabetic(before) or option_name or (std.ascii.isLower(before) and std.ascii.isUpper(first));
            const right = !std.ascii.isAlphabetic(after) or (std.ascii.isUpper(after) and std.ascii.isLower(last));
            return left and right;
        },
        .enum_literal => {
            // Something a member is reached from stands before a member
            // access: an identifier (`std.testing`), a call or an index.
            if (isIdentChar(before) or before == ')' or before == ']' or before == '}' or before == '?' or before == '*' or before == '.') return false;
            return !isIdentChar(after);
        },
    }
}

/// Where the `//` comment of a line begins (the line's length when it has
/// none): the first `//` outside a "..." string and a '...' character.
fn commentStart(line: []const u8) usize {
    var quote: u8 = 0;
    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        const c = line[i];
        if (quote != 0) {
            if (c == '\\') {
                i += 1;
            } else if (c == quote) {
                quote = 0;
            }
            continue;
        }
        if (c == '"' or c == '\'') {
            quote = c;
        } else if (c == '/' and i + 1 < line.len and line[i + 1] == '/') {
            return i;
        }
    }
    return line.len;
}

/// The token line ranges of every `test` declaration in `source`, 1-based and
/// inclusive. A file that does not parse yields none (its lines all count).
fn testLines(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList([2]u32) {
    var out: std.ArrayList([2]u32) = .empty;
    errdefer out.deinit(gpa);
    var tree = try std.zig.Ast.parse(gpa, source, .{ .mode = .zig });
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return out;
    var i: u32 = 0;
    while (i < tree.nodes.len) : (i += 1) {
        const node: std.zig.Ast.Node.Index = @fromBackingInt(@intCast(i));
        if (tree.nodeTag(node) != .test_decl) continue;
        const first: u32 = @intCast(tree.tokenLocation(0, tree.firstToken(node)).line + 1);
        const last: u32 = @intCast(tree.tokenLocation(0, tree.lastToken(node)).line + 1);
        try out.append(gpa, .{ first, last });
    }
    return out;
}

fn inTest(ranges: []const [2]u32, line: u32) bool {
    for (ranges) |r| if (line >= r[0] and line <= r[1]) return true;
    return false;
}

/// One occurrence of a key.
pub const Site = struct {
    line: u32,
    /// Index into the keys the scan was given.
    key: usize,
    kind: Kind,
    /// The line, trimmed, for the report.
    text: []const u8,
};

/// What a file's scan found.
pub const FileScan = struct {
    /// Every occurrence, in line order.
    sites: std.ArrayList(Site) = .empty,
    /// Per class, the lines that hold a key of it, by what the line is - its
    /// first characters say: a comment, a script line or code.
    lines: [classes.len][3]u32 = @splat(@splat(0)),
    /// The repo-relative paths of the `.zig` files it imports.
    imports: std.ArrayList([]const u8) = .empty,

    pub fn deinit(scan: *FileScan, gpa: std.mem.Allocator) void {
        scan.sites.deinit(gpa);
        for (scan.imports.items) |path| gpa.free(path);
        scan.imports.deinit(gpa);
    }
};

/// `import_path` as written in the file at `importer`, repo-relative and
/// normalized; null when it leaves the repository.
pub fn resolveImport(gpa: std.mem.Allocator, importer: []const u8, import_path: []const u8) !?[]u8 {
    var segments: std.ArrayList([]const u8) = .empty;
    defer segments.deinit(gpa);
    const dir_end = std.mem.lastIndexOfScalar(u8, importer, '/');
    if (dir_end) |end| {
        var dir_parts = std.mem.splitScalar(u8, importer[0..end], '/');
        while (dir_parts.next()) |part| try segments.append(gpa, part);
    }
    var parts = std.mem.splitScalar(u8, import_path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            if (segments.items.len == 0) return null;
            _ = segments.pop();
            continue;
        }
        try segments.append(gpa, part);
    }
    return try std.mem.join(gpa, "/", segments.items);
}

/// Scan the file at `path` (repo-relative) with contents `text`. Sites'
/// `text` are slices of `text`.
pub fn scanFile(gpa: std.mem.Allocator, path: []const u8, text: []const u8, keys: []const Key) !FileScan {
    var out: FileScan = .{};
    errdefer out.deinit(gpa);
    const scope = scopeOf(path);

    const source = try gpa.dupeSentinel(u8, text, 0);
    defer gpa.free(source);
    var tests = try testLines(gpa, source);
    defer tests.deinit(gpa);

    var lines = std.mem.splitScalar(u8, text, '\n');
    var line_no: u32 = 0;
    while (lines.next()) |raw| {
        line_no += 1;
        if (inTest(tests.items, line_no)) continue;
        const trimmed = std.mem.trim(u8, raw, " \t\r");
        if (trimmed.len == 0) continue;
        const script = std.mem.startsWith(u8, trimmed, "\\\\");
        const comment_at = if (script) raw.len else commentStart(raw);
        const line_kind: Kind = if (script) .script else if (std.mem.startsWith(u8, trimmed, "//")) .comment else .code;

        // Imports: a literal path to a .zig file, in code.
        if (!script) {
            const code = raw[0..comment_at];
            const open = "@import(\"";
            var search: usize = 0;
            while (std.mem.indexOfPos(u8, code, search, open)) |at| {
                const start = at + open.len;
                const end = std.mem.indexOfScalarPos(u8, code, start, '"') orelse break;
                search = end + 1;
                const import_path = code[start..end];
                if (!std.mem.endsWith(u8, import_path, ".zig")) continue;
                if (try resolveImport(gpa, path, import_path)) |resolved| {
                    errdefer gpa.free(resolved);
                    try out.imports.append(gpa, resolved);
                }
            }
        }

        if (scope == .none) continue;
        var class_hit: [classes.len]bool = @splat(false);
        for (keys, 0..) |key, key_index| {
            if (scope == .engine_only and key.class != .engine) continue;
            if (script and !key.class.countedInScripts()) continue;
            var at: usize = 0;
            while (at + key.text.len <= raw.len) : (at += 1) {
                if (!matchesAt(raw, at, key)) continue;
                const kind: Kind = if (script) .script else if (at >= comment_at) .comment else .code;
                try out.sites.append(gpa, .{ .line = line_no, .key = key_index, .kind = kind, .text = trimmed });
                class_hit[@backingInt(key.class)] = true;
                at += key.text.len - 1;
            }
        }
        for (class_hit, 0..) |hit, class_index| {
            if (hit) out.lines[class_index][@backingInt(line_kind)] += 1;
        }
    }
    return out;
}

/// What `--update` is told: the rule has nothing to record.
pub const no_baseline =
    \\lint-build is a plain rule since the build migration's last batch (P4, 2026-11-24):
    \\no name of an engine, an operating system or a platform library is recorded -
    \\each moves behind its protocol's build side, or is said without the name.
    \\There is no baseline to update.
    \\
;

/// What every failure ends with.
const explanation =
    \\
    \\build.zig and the neutral files it imports name no engine, no operating
    \\system and no platform library (the user, 2026-11-12). What is an adapter's
    \\goes in the adapter's own build file, behind the build side of its protocol
    \\(src/runtime/engine_build_protocol.zig, src/platform/platform_build_protocol.zig
    \\and the kit's src/platform/kit/kit_build.zig); the root build asks the protocol.
    \\
;

/// Whether the tree fails for its baseline file, printing why: the ratchet's
/// baseline, retired at zero, is refused - not read - if it comes back.
pub fn refuseBaseline(out: *std.Io.Writer, exists: bool) !bool {
    if (!exists) return false;
    try out.print(
        \\build neutrality: {s} exists. The rule has no baseline since the build
        \\migration's last batch (P4, 2026-11-24) - every name fails - so the file is
        \\refused, not read: delete it, and move what it would record.
        \\
    , .{retired_baseline_path});
    return true;
}

/// The verdict on a scan: every occurrence of a key in a counted file is a
/// failure, printed with its site; none is a pass. True when the tree fails.
pub fn report(out: *std.Io.Writer, files: []const FileSites, keys: []const Key, counted_files: usize) !bool {
    var found: usize = 0;
    for (files) |file| found += file.sites.len;
    if (found == 0) {
        try out.print("build neutrality: {d} files name no engine, no operating system and no platform library.\n", .{counted_files});
        return false;
    }
    try out.print("build neutrality: {d} name(s) of an engine, an operating system or a platform library.\n\n", .{found});
    for (files) |file| {
        for (file.sites) |site| {
            const key = keys[site.key];
            try out.print("  {s}:{d} {t}:{s} {t}: {s}\n", .{ file.path, site.line, key.class, key.text, site.kind, site.text });
        }
    }
    try out.writeAll(explanation);
    return true;
}

/// The whole tree's totals, per class.
const Totals = struct {
    occurrences: [classes.len]u32 = @splat(0),
    lines: [classes.len][3]u32 = @splat(@splat(0)),

    fn print(totals: *const Totals, out: *std.Io.Writer) !void {
        for (classes) |class| {
            const i = @backingInt(class);
            const l = totals.lines[i];
            const code = l[@backingInt(Kind.code)];
            const comment = l[@backingInt(Kind.comment)];
            const script = l[@backingInt(Kind.script)];
            try out.print("  {t}: {d} lines ({d} code, {d} comments, {d} script), {d} occurrences\n", .{ class, code + comment + script, code, comment, script, totals.occurrences[i] });
        }
    }
};

/// A file's occurrences, kept for the report, and its lines per class.
pub const FileSites = struct {
    path: []const u8,
    sites: []const Site,
    lines: [classes.len][3]u32,

    /// `  build.zig: engine 518 lines, platform 180, target 29, library 404`
    /// - where the totals are, file by file; nothing for a file that names
    /// nothing.
    fn print(file: *const FileSites, out: *std.Io.Writer) !void {
        var any = false;
        for (file.lines) |per_kind| {
            if (per_kind[0] + per_kind[1] + per_kind[2] != 0) any = true;
        }
        if (!any) return;
        try out.print("  {s}:", .{file.path});
        for (classes, 0..) |class, n| {
            const l = file.lines[@backingInt(class)];
            try out.print("{s} {t} {d}{s}", .{ if (n == 0) "" else ",", class, l[0] + l[1] + l[2], if (n == 0) " lines" else "" });
        }
        try out.print("\n", .{});
    }
};

fn usage() noreturn {
    std.debug.print("usage: lint_build_neutral [--engine=<keys>] [--platform=<keys>] [--target=<keys>] [--library=<keys>] [--list]\n", .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var list = false;
    var keys: std.ArrayList(Key) = .empty;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    next_arg: while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) {
            std.debug.print("{s}", .{no_baseline});
            std.process.exit(2);
        }
        if (std.mem.eql(u8, arg, "--list")) {
            list = true;
            continue;
        }
        for (classes) |class| {
            if (std.mem.startsWith(u8, arg, class.flag())) {
                try parseKeys(arena, &keys, class, try arena.dupe(u8, arg[class.flag().len..]));
                continue :next_arg;
            }
        }
        usage();
    }

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    // The retired baseline is refused if it comes back: the rule has none.
    const baseline_back = if (std.Io.Dir.cwd().access(io, retired_baseline_path, .{})) |_| true else |err| switch (err) {
        error.FileNotFound => false,
        else => return err,
    };
    if (try refuseBaseline(out, baseline_back)) {
        try out.flush();
        std.process.exit(1);
    }

    // The root and everything reached from it, each file once.
    var totals: Totals = .{};
    var scanned: std.ArrayList(FileSites) = .empty;
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    var queue: std.ArrayList([]const u8) = .empty;
    try queue.append(arena, root_path);
    try seen.put(arena, root_path, {});
    var counted_files: usize = 0;
    var next: usize = 0;
    while (next < queue.items.len) : (next += 1) {
        const path = queue.items[next];
        const text = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20)) catch |err| switch (err) {
            // An import of a file that is not there fails the build itself.
            error.FileNotFound => continue,
            else => return err,
        };
        const scan = try scanFile(arena, path, text, keys.items);
        for (scan.imports.items) |import_path| {
            const gop = try seen.getOrPut(arena, import_path);
            if (!gop.found_existing) try queue.append(arena, import_path);
        }
        if (scopeOf(path) == .none) continue;
        counted_files += 1;
        try scanned.append(arena, .{ .path = path, .sites = scan.sites.items, .lines = scan.lines });
        for (scan.sites.items) |site| totals.occurrences[@backingInt(keys.items[site.key].class)] += 1;
        for (classes) |class| {
            const i = @backingInt(class);
            for (0..3) |k| totals.lines[i][k] += scan.lines[i][k];
        }
    }

    if (list) {
        for (scanned.items) |file| {
            for (file.sites) |site| {
                const key = keys.items[site.key];
                try out.print("{s}:{d} {t}:{s} {t}: {s}\n", .{ file.path, site.line, key.class, key.text, site.kind, site.text });
            }
        }
    }

    const failed = try report(out, scanned.items, keys.items, counted_files);
    try totals.print(out);
    for (scanned.items) |*file| try file.print(out);
    if (failed) {
        try out.flush();
        std.process.exit(1);
    }
}

// ============================================================================
// Tests - the rules
// ============================================================================

const testing = std.testing;

/// The keys build.zig passes today, as the tests' fixture.
const test_engine_keys = "v8,jsc,javascriptcore,quickjs";
const test_platform_keys = "darwin,linux,macos,word:ios,iphoneos,xcrun,homebrew,.testing";
const test_target_keys = "os.tag,isDarwin,.abi ==";
const test_library_keys = "curl,mbedtls,nghttp2,brotli,zlib,sqlite,leveldb,jpeg,expat,nanosvg";

fn testKeys(arena: std.mem.Allocator) ![]const Key {
    var keys: std.ArrayList(Key) = .empty;
    try parseKeys(arena, &keys, .engine, test_engine_keys);
    try parseKeys(arena, &keys, .platform, test_platform_keys);
    try parseKeys(arena, &keys, .target, test_target_keys);
    try parseKeys(arena, &keys, .library, test_library_keys);
    return keys.items;
}

/// `expected`: one "line:class:key kind" per occurrence, in order.
fn expectSites(path: []const u8, text: []const u8, expected: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const keys = try testKeys(arena.allocator());
    const scan = try scanFile(arena.allocator(), path, text, keys);
    var got: std.ArrayList(u8) = .empty;
    for (scan.sites.items) |site| {
        const key = keys[site.key];
        try got.print(arena.allocator(), "{d}:{t}:{s} {t}\n", .{ site.line, key.class, key.text, site.kind });
    }
    var want: std.ArrayList(u8) = .empty;
    for (expected) |e| try want.print(arena.allocator(), "{s}\n", .{e});
    try testing.expectEqualStrings(want.items, got.items);
}

test "scope: the engine's build files are not counted, the platform's only for engines, the rest for everything" {
    try testing.expectEqual(Scope.all, scopeOf("build.zig"));
    try testing.expectEqual(Scope.all, scopeOf("tools/test_suites.zig"));
    try testing.expectEqual(Scope.all, scopeOf("tests/wpt_runner/build_mode.zig"));
    // A neutral file beside the protocol's build file is neutral.
    try testing.expectEqual(Scope.all, scopeOf("src/runtime/engine_protocol.zig"));
    try testing.expectEqual(Scope.none, scopeOf("src/runtime/engine_build_protocol.zig"));
    try testing.expectEqual(Scope.none, scopeOf("src/platform/platform_build_protocol.zig"));
    try testing.expectEqual(Scope.none, scopeOf("src/runtime/engines/v8/engine_build.zig"));
    try testing.expectEqual(Scope.none, scopeOf("src/runtime/engines/v8/build/archives.zig"));
    try testing.expectEqual(Scope.none, scopeOf("src/runtime/engines/jsc/engine_build.zig"));
    try testing.expectEqual(Scope.engine_only, scopeOf("src/platform/build_protocol.zig"));
    try testing.expectEqual(Scope.engine_only, scopeOf("src/platform/adapters/darwin/platform_build.zig"));
    try testing.expectEqual(Scope.engine_only, scopeOf("src/platform/kit/kit_build.zig"));
}

test "an engine's name counts wherever it occurs in code: an identifier, a string, an option" {
    try expectSites("build.zig",
        \\const v8_archives = @import("tools/v8_archives.zig");
        \\fn linkV8(b: *std.Build, v8: V8Link) void {}
        \\const engines = [_][]const u8{ "jsc", "quickjs" };
        \\const flag = b.option(bool, "jitless", "Run V8 without JIT");
        \\module.addObjectFile(b.path("libv8_monolith.a"));
        \\const framework = "JavaScriptCore";
    , &.{
        "1:engine:v8 code",
        "1:engine:v8 code",
        "2:engine:v8 code",
        "2:engine:v8 code",
        "2:engine:v8 code",
        "3:engine:jsc code",
        "3:engine:quickjs code",
        "4:engine:v8 code",
        "5:engine:v8 code",
        "6:engine:javascriptcore code",
    });
}

test "a comment counts as a comment, a trailing one too; a // inside a string is not a comment" {
    try expectSites("build.zig",
        \\// The V8 wrapper is compiled apart.
        \\/// Links QuickJS when asked.
        \\const x = 1; // V8 needs it
        \\const url = "https://v8.dev/"; // the engine's site
    , &.{
        "1:engine:v8 comment",
        "2:engine:quickjs comment",
        "3:engine:v8 comment",
        "4:engine:v8 code",
    });
}

test "an embedded script counts for engines and operating systems, never for a library" {
    try expectSites("build.zig",
        \\const script =
        \\    \\# Build V8 for macOS
        \\    \\curl -L https://example.org/v8.tar.gz | tar xz
        \\    \\brew install sqlite
        \\;
    , &.{
        "2:engine:v8 script",
        "2:platform:macos script",
        "3:engine:v8 script",
    });
}

test "an operating system: its names, the word ios, and the enum literal .testing" {
    try expectSites("build.zig",
        \\if (target.result.os.tag == .ios) addIosSdkPaths(b, module, ios_sdk);
        \\const scenarios = radios ++ biosensors; // not iOS's
        \\const sdk_option = b.option([]const u8, "ios-sdk", "-Dios-sdk=<path>");
        \\const homebrew = "/opt/homebrew/lib";
        \\const sdk = run(&.{ "xcrun", "--sdk", "iphoneos" });
        \\const graph = if (platform == .testing) shared else std.testing.allocator;
        \\if (t.isDarwin()) frameworks(m) else if (t.os.tag == .linux and t.abi == .gnu) {}
        \\const name = "aarch64-macos-none"; // or x86_64-linux-none
    , &.{
        "1:platform:ios code",
        "1:platform:ios code",
        "1:platform:ios code",
        "1:target:os.tag code",
        "2:platform:ios comment",
        "3:platform:ios code",
        "3:platform:ios code",
        "4:platform:homebrew code",
        "4:platform:homebrew code",
        "5:platform:iphoneos code",
        "5:platform:xcrun code",
        "6:platform:.testing code",
        "7:platform:darwin code",
        "7:platform:linux code",
        "7:target:os.tag code",
        "7:target:isDarwin code",
        "7:target:.abi == code",
        "8:platform:linux comment",
        "8:platform:macos code",
    });
}

test "a branch on the target is matched by its case; a name is not" {
    try expectSites("build.zig",
        \\const a = t.OS.TAG; // not the field
        \\const b = "LINUX";
    , &.{
        "2:platform:linux code",
    });
}

test "a platform library: its name in code and comments" {
    try expectSites("build.zig",
        \\fn buildStaticLibcurl(b: *std.Build) void {}
        \\// mbedTLS and zlib come with it; nghttp2 when asked.
        \\module.linkSystemLibrary("sqlite3", .{});
        \\const codecs = .{ "jpeg", "expat", "nanosvg", "brotli", "leveldb" };
    , &.{
        "1:library:curl code",
        "2:library:mbedtls comment",
        "2:library:nghttp2 comment",
        "2:library:zlib comment",
        "3:library:sqlite code",
        "4:library:brotli code",
        "4:library:leveldb code",
        "4:library:jpeg code",
        "4:library:expat code",
        "4:library:nanosvg code",
    });
}

test "test declarations are exempt, and their imports are not followed" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const keys = try testKeys(arena.allocator());
    const scan = try scanFile(arena.allocator(), "tools/test_suites.zig",
        \\const std = @import("std");
        \\const helper = @import("suite_rows.zig");
        \\pub const alone = "v8";
        \\test "the v8 suite runs alone on linux" {
        \\    const fixture = @import("fixtures/v8_rows.zig");
        \\    try std.testing.expect(fixture.rows.len > 0);
        \\}
    , keys);
    try testing.expectEqual(@as(usize, 1), scan.sites.items.len);
    try testing.expectEqual(@as(u32, 3), scan.sites.items[0].line);
    try testing.expectEqual(@as(usize, 1), scan.imports.items.len);
    try testing.expectEqualStrings("tools/suite_rows.zig", scan.imports.items[0]);
}

test "an engine's build file is not counted, but what it imports is found" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const keys = try testKeys(arena.allocator());
    const scan = try scanFile(arena.allocator(), "src/runtime/engines/v8/engine_build.zig",
        \\const std = @import("std");
        \\const archives = @import("build/archives.zig");
        \\const test_suites = @import("../../../../tools/test_suites.zig");
        \\pub const words = [_][]const u8{"v8"};
        \\const ios = target.result.os.tag == .ios;
    , keys);
    try testing.expectEqual(@as(usize, 0), scan.sites.items.len);
    try testing.expectEqual(@as(usize, 2), scan.imports.items.len);
    try testing.expectEqualStrings("src/runtime/engines/v8/build/archives.zig", scan.imports.items[0]);
    try testing.expectEqualStrings("tools/test_suites.zig", scan.imports.items[1]);
}

test "a platform build file may name its operating system and libraries, never an engine" {
    try expectSites("src/platform/adapters/darwin/platform_build.zig",
        \\// macOS frameworks; curl comes from the kit.
        \\if (target.result.os.tag == .ios) sdk(b);
        \\// V8's archive needs CoreFoundation too.
    , &.{
        "3:engine:v8 comment",
    });
}

test "an import is resolved from its importer; one that leaves the repository is dropped" {
    const cases = [_]struct { importer: []const u8, path: []const u8, want: ?[]const u8 }{
        .{ .importer = "build.zig", .path = "tools/test_suites.zig", .want = "tools/test_suites.zig" },
        .{ .importer = "build.zig", .path = "./tools/x.zig", .want = "tools/x.zig" },
        .{ .importer = "src/runtime/engine_build_protocol.zig", .path = "engines/v8/engine_build.zig", .want = "src/runtime/engines/v8/engine_build.zig" },
        .{ .importer = "src/runtime/engines/v8/engine_build.zig", .path = "../../engine_build_protocol.zig", .want = "src/runtime/engine_build_protocol.zig" },
        .{ .importer = "tools/a.zig", .path = "../../outside.zig", .want = null },
    };
    for (cases) |case| {
        const got = try resolveImport(testing.allocator, case.importer, case.path);
        defer if (got) |path| testing.allocator.free(path);
        if (case.want) |want| {
            try testing.expectEqualStrings(want, got orelse return error.TestExpectedAPath);
        } else try testing.expect(got == null);
    }
}

test "lines are totalled per class by what the line is, each line once" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const keys = try testKeys(arena.allocator());
    const scan = try scanFile(arena.allocator(), "build.zig",
        \\// V8 and JavaScriptCore on macOS
        \\linkV8(b, exe, v8); // the V8 archives
        \\const s =
        \\    \\build-v8.sh --linux
        \\;
        \\const plain = 1;
    , keys);
    const engine = scan.lines[@backingInt(Class.engine)];
    try testing.expectEqual(@as(u32, 1), engine[@backingInt(Kind.code)]);
    try testing.expectEqual(@as(u32, 1), engine[@backingInt(Kind.comment)]);
    try testing.expectEqual(@as(u32, 1), engine[@backingInt(Kind.script)]);
    const platform = scan.lines[@backingInt(Class.platform)];
    try testing.expectEqual(@as(u32, 0), platform[@backingInt(Kind.code)]);
    try testing.expectEqual(@as(u32, 1), platform[@backingInt(Kind.comment)]);
    try testing.expectEqual(@as(u32, 1), platform[@backingInt(Kind.script)]);
    // Six occurrences on those three engine lines: two, three (two in code,
    // one in its comment) and one.
    var engine_sites: usize = 0;
    for (scan.sites.items) |site| {
        if (keys[site.key].class == .engine) engine_sites += 1;
    }
    try testing.expectEqual(@as(usize, 6), engine_sites);
}

test "keys: a plain key is a substring, word: a word, a dotted name an enum literal" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var keys: std.ArrayList(Key) = .empty;
    try parseKeys(arena.allocator(), &keys, .platform, "linux, word:ios,.testing,,word:");
    try parseKeys(arena.allocator(), &keys, .target, "os.tag,.abi ==");
    try testing.expectEqual(@as(usize, 5), keys.items.len);
    try testing.expectEqualStrings("linux", keys.items[0].text);
    try testing.expectEqual(Match.substring, keys.items[0].match);
    try testing.expectEqualStrings("ios", keys.items[1].text);
    try testing.expectEqual(Match.word, keys.items[1].match);
    try testing.expectEqualStrings(".testing", keys.items[2].text);
    try testing.expectEqual(Match.enum_literal, keys.items[2].match);
    try testing.expectEqual(Match.substring, keys.items[3].match);
    // `.abi ==` is text, not an enum literal.
    try testing.expectEqualStrings(".abi ==", keys.items[4].text);
    try testing.expectEqual(Match.substring, keys.items[4].match);
    try testing.expectEqual(Class.target, keys.items[4].class);
}

/// The report on `text` scanned as the file at `path`: whether it failed, and what it printed.
fn reportOn(arena: std.mem.Allocator, path: []const u8, text: []const u8) !struct { bool, []const u8 } {
    const keys = try testKeys(arena);
    const scan = try scanFile(arena, path, text, keys);
    var out: std.Io.Writer.Allocating = .init(arena);
    const files = [_]FileSites{.{ .path = path, .sites = scan.sites.items, .lines = scan.lines }};
    const failed = try report(&out.writer, &files, keys, files.len);
    return .{ failed, out.written() };
}

test "any name of an engine, an OS or a platform library fails, each site printed - there is no baseline" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const failed, const printed = try reportOn(arena.allocator(), "build.zig",
        \\const ok = 1;
        \\// System frameworks (macOS)
        \\const lib = "curl";
    );
    try testing.expect(failed);
    try testing.expect(std.mem.indexOf(u8, printed, "build.zig:2 platform:macos comment: // System frameworks (macOS)") != null);
    try testing.expect(std.mem.indexOf(u8, printed, "build.zig:3 library:curl code: const lib = \"curl\";") != null);
    try testing.expect(std.mem.indexOf(u8, printed, "2 name(s)") != null);
}

test "a tree that names none passes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const failed, const printed = try reportOn(arena.allocator(), "build.zig",
        \\const os_side = platform_build.chooseOs(b, target, build_probe);
        \\// What the target's C needs that Zig does not find by itself.
    );
    try testing.expect(!failed);
    try testing.expect(std.mem.indexOf(u8, printed, "1 files name no engine, no operating system and no platform library") != null);
}

test "the rule keeps no baseline: --update is refused, and so is the retired baseline if it comes back" {
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try testing.expect(!try refuseBaseline(&out.writer, false));
    try testing.expectEqual(@as(usize, 0), out.written().len);
    try testing.expect(try refuseBaseline(&out.writer, true));
    try testing.expect(std.mem.indexOf(u8, out.written(), "tools/build_neutral_baseline.txt exists") != null);
    try testing.expect(std.mem.indexOf(u8, no_baseline, "There is no baseline to update.") != null);
}

test {
    _ = stdout_stream;
}
