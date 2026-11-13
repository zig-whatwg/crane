//! The build's neutrality, as a ratchet: `zig build lint-build` (and so `zig
//! build test`) fails when build.zig, or a file it imports, names an engine,
//! an operating system or a platform library more often than
//! tools/build_neutral_baseline.txt records.
//!
//! The rule (the user, 2026-11-12): no engine- or platform-specific code in
//! build.zig. An adapter declares its build options, sources and link inputs
//! in its own build file, behind the build side of its protocol
//! (src/runtime/engine_build_protocol.zig; the platform's follows), and the
//! root build names no adapter. The migration that gets there moves a slice
//! per batch (tmp/plans/build-protocol-design.md); this lint holds what each
//! batch gained.
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
//! A count that rises fails, and so does a (file, key, kind) the baseline
//! lacks - which catches a swap. The baseline only goes down. After a batch
//! moves a slice out:
//!     zig build lint-build -- --update
//! which refuses to record an increase. `-- --list` prints every site: the
//! work list. When the baseline is empty the lint is a plain rule.

const std = @import("std");
// stdout as a stream: Zig 0.17's positional File.writer overwrites a shared log.
const stdout_stream = @import("stdout_stream.zig");

const baseline_path = "tools/build_neutral_baseline.txt";

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

/// Counts per "path class:key kind" key.
pub const Counts = std.StringHashMapUnmanaged(u32);

/// The baseline key of an occurrence of `key`, of `kind`, in the file at `path`.
pub fn countKey(gpa: std.mem.Allocator, path: []const u8, key: Key, kind: Kind) ![]u8 {
    return std.fmt.allocPrint(gpa, "{s} {t}:{s} {t}", .{ path, key.class, key.text, kind });
}

/// A key the current tree has more of than the baseline allows.
pub const Violation = struct { key: []const u8, allowed: u32, found: u32 };

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn violationLessThan(_: void, a: Violation, b: Violation) bool {
    return std.mem.lessThan(u8, a.key, b.key);
}

/// Every key in `current` above its baseline count - a key absent from the
/// baseline is allowed zero - sorted by key.
pub fn violations(gpa: std.mem.Allocator, current: *const Counts, baseline: *const Counts) !std.ArrayList(Violation) {
    var out: std.ArrayList(Violation) = .empty;
    errdefer out.deinit(gpa);
    var it = current.iterator();
    while (it.next()) |entry| {
        const allowed = baseline.get(entry.key_ptr.*) orelse 0;
        if (entry.value_ptr.* > allowed) {
            try out.append(gpa, .{ .key = entry.key_ptr.*, .allowed = allowed, .found = entry.value_ptr.* });
        }
    }
    std.mem.sort(Violation, out.items, {}, violationLessThan);
    return out;
}

/// Parse a baseline file: `path class:key kind count` per line, `#` comments.
/// A key may hold spaces, so the count is what follows the last one. Keys
/// are allocated with `gpa` and owned by the map.
pub fn parseBaseline(gpa: std.mem.Allocator, text: []const u8) !Counts {
    var counts: Counts = .empty;
    errdefer {
        var keys = counts.keyIterator();
        while (keys.next()) |key| gpa.free(key.*);
        counts.deinit(gpa);
    }
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const space = std.mem.lastIndexOfScalar(u8, line, ' ') orelse return error.MalformedBaseline;
        const count = std.fmt.parseInt(u32, line[space + 1 ..], 10) catch return error.MalformedBaseline;
        const key = try gpa.dupe(u8, std.mem.trimEnd(u8, line[0..space], " "));
        errdefer gpa.free(key);
        const gop = try counts.getOrPut(gpa, key);
        if (gop.found_existing) {
            gpa.free(key);
            gop.value_ptr.* += count;
        } else gop.value_ptr.* = count;
    }
    return counts;
}

const header =
    \\# What build.zig and the neutral files it imports still name of an engine, an
    \\# operating system or a platform library: path class:key kind count.
    \\# A ratchet - `zig build lint-build`, part of `zig build test`, fails if any
    \\# count rises or a new line appears. After a batch moves a slice behind the
    \\# build side of a protocol (src/runtime/engine_build_protocol.zig), lower it
    \\# with `zig build lint-build -- --update`. Never raise it by hand.
    \\
;

/// Format counts as a baseline file, keys sorted.
pub fn formatBaseline(gpa: std.mem.Allocator, counts: *const Counts) ![]u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(gpa);
    var it = counts.keyIterator();
    while (it.next()) |key| try keys.append(gpa, key.*);
    std.mem.sort([]const u8, keys.items, {}, lessThan);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, header);
    for (keys.items) |key| {
        const line = try std.fmt.allocPrint(gpa, "{s} {d}\n", .{ key, counts.get(key).? });
        defer gpa.free(line);
        try out.appendSlice(gpa, line);
    }
    return out.toOwnedSlice(gpa);
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
const FileSites = struct {
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

/// A violation lists its key's sites only up to this many.
const max_sites_printed = 20;

fn usage() noreturn {
    std.debug.print("usage: lint_build_neutral [--engine=<keys>] [--platform=<keys>] [--target=<keys>] [--library=<keys>] [--update] [--list]\n", .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var update = false;
    var list = false;
    var keys: std.ArrayList(Key) = .empty;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    next_arg: while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) {
            update = true;
            continue;
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

    // The root and everything reached from it, each file once.
    var current: Counts = .empty;
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
        for (scan.sites.items) |site| {
            const key = keys.items[site.key];
            const gop = try current.getOrPut(arena, try countKey(arena, path, key, site.kind));
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
            totals.occurrences[@backingInt(key.class)] += 1;
        }
        for (classes) |class| {
            const i = @backingInt(class);
            for (0..3) |k| totals.lines[i][k] += scan.lines[i][k];
        }
    }

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    if (list) {
        for (scanned.items) |file| {
            for (file.sites) |site| {
                const key = keys.items[site.key];
                try out.print("{s}:{d} {t}:{s} {t}: {s}\n", .{ file.path, site.line, key.class, key.text, site.kind, site.text });
            }
        }
    }

    const text: ?[]u8 = std.Io.Dir.cwd().readFileAlloc(io, baseline_path, arena, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (text == null) {
        if (!update) {
            try out.print("build neutrality: no {s}; record one with `zig build lint-build -- --update`.\n", .{baseline_path});
            try out.flush();
            std.process.exit(1);
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("build neutrality: first baseline recorded - {d} files, {d} keys.\n", .{ counted_files, current.count() });
        try totals.print(out);
        for (scanned.items) |*file| try file.print(out);
        return;
    }
    const baseline = try parseBaseline(arena, text.?);

    const found = try violations(arena, &current, &baseline);
    if (found.items.len > 0) {
        try out.print("build neutrality: {d} key(s) above the baseline.\n\n", .{found.items.len});
        for (found.items) |v| {
            try out.print("  {s}: allowed {d}, found {d}\n", .{ v.key, v.allowed, v.found });
            // A key with hundreds of sites would bury the new one: the
            // change's own diff holds it.
            if (v.found > max_sites_printed) {
                try out.print("      ({d} sites: `zig build lint-build -- --list` prints them; the new one is in your diff)\n", .{v.found});
                continue;
            }
            for (scanned.items) |file| {
                for (file.sites) |site| {
                    const site_key = try countKey(arena, file.path, keys.items[site.key], site.kind);
                    if (std.mem.eql(u8, site_key, v.key)) try out.print("      {s}:{d}: {s}\n", .{ file.path, site.line, site.text });
                }
            }
        }
        try out.print(
            \\
            \\build.zig and the neutral files it imports name no engine, no operating
            \\system and no platform library (the user, 2026-11-12). What is an adapter's
            \\goes in the adapter's own build file, behind the build side of its protocol
            \\(src/runtime/engine_build_protocol.zig); the root build asks the protocol.
            \\
        , .{});
        try out.flush();
        std.process.exit(1);
    }

    var lowered: usize = 0;
    var base_it = baseline.iterator();
    while (base_it.next()) |entry| {
        if ((current.get(entry.key_ptr.*) orelse 0) < entry.value_ptr.*) lowered += 1;
    }
    if (update) {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("build neutrality: baseline lowered - {d} files, {d} keys.\n", .{ counted_files, current.count() });
    } else if (lowered > 0) {
        try out.print("build neutrality: {d} key(s) paid down; record it with `zig build lint-build -- --update`.\n", .{lowered});
    } else {
        try out.print("build neutrality: {d} files, {d} keys, none above the baseline.\n", .{ counted_files, current.count() });
    }
    try totals.print(out);
    for (scanned.items) |*file| try file.print(out);
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

test "a violation is any key above its baseline, including a key the baseline lacks (a swap, or code that became a comment)" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    var baseline: Counts = .empty;
    defer baseline.deinit(testing.allocator);

    try baseline.put(testing.allocator, "build.zig engine:v8 code", 190);
    try baseline.put(testing.allocator, "build.zig engine:v8 comment", 218);
    try baseline.put(testing.allocator, "build.zig platform:linux code", 20);
    // Paid down: fewer is always allowed.
    try current.put(testing.allocator, "build.zig engine:v8 code", 150);
    // Grown.
    try current.put(testing.allocator, "build.zig engine:v8 comment", 219);
    // The same total as before under another key: one name swapped for another.
    try current.put(testing.allocator, "build.zig platform:linux code", 19);
    try current.put(testing.allocator, "build.zig platform:darwin code", 1);
    // A file the baseline never had.
    try current.put(testing.allocator, "tools/new_helper.zig engine:v8 code", 1);

    var found = try violations(testing.allocator, &current, &baseline);
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), found.items.len);
    try testing.expectEqualStrings("build.zig engine:v8 comment", found.items[0].key);
    try testing.expectEqual(@as(u32, 218), found.items[0].allowed);
    try testing.expectEqual(@as(u32, 219), found.items[0].found);
    try testing.expectEqualStrings("build.zig platform:darwin code", found.items[1].key);
    try testing.expectEqual(@as(u32, 0), found.items[1].allowed);
    try testing.expectEqualStrings("tools/new_helper.zig engine:v8 code", found.items[2].key);
}

test "the baseline round-trips, sorted, with a key that holds a space, and ignores comments" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const keys = try testKeys(arena.allocator());
    var abi: ?Key = null;
    for (keys) |key| {
        if (std.mem.eql(u8, key.text, ".abi ==")) abi = key;
    }

    var counts: Counts = .empty;
    defer counts.deinit(testing.allocator);
    const abi_key = try countKey(testing.allocator, "build.zig", abi.?, .code);
    defer testing.allocator.free(abi_key);
    try testing.expectEqualStrings("build.zig target:.abi == code", abi_key);
    try counts.put(testing.allocator, abi_key, 2);
    try counts.put(testing.allocator, "build.zig engine:v8 script", 90);
    try counts.put(testing.allocator, "build.zig engine:v8 code", 191);

    const text = try formatBaseline(testing.allocator, &counts);
    defer testing.allocator.free(text);
    try testing.expect(std.mem.indexOf(u8, text, "build.zig engine:v8 code 191\nbuild.zig engine:v8 script 90\nbuild.zig target:.abi == code 2\n") != null);

    var parsed = try parseBaseline(testing.allocator, text);
    defer {
        var it = parsed.keyIterator();
        while (it.next()) |key| testing.allocator.free(key.*);
        parsed.deinit(testing.allocator);
    }
    try testing.expectEqual(@as(u32, 3), parsed.count());
    try testing.expectEqual(@as(u32, 2), parsed.get("build.zig target:.abi == code").?);
    try testing.expectEqual(@as(u32, 191), parsed.get("build.zig engine:v8 code").?);
    try testing.expectError(error.MalformedBaseline, parseBaseline(testing.allocator, "build.zig engine:v8 code many\n"));
}

test {
    _ = stdout_stream;
}
