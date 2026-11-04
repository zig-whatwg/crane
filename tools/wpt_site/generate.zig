//! Crane's public WPT results site: the generator.
//!
//!     zig build wpt-site [-- --out=<dir> --no-commit ...]
//!
//! Reads the progress report's accumulated state and history, the worklist,
//! and any per-subtest wptreport streams, and writes the site to --out as
//! finished HTML: index.html, one page per directory of the WPT tree, one per
//! test file, the stylesheet and faces from tools/wpt_site/assets/, and the
//! social card (card.png), and paths.json for the search. No page needs
//! script for its content; site.js (an asset) enhances every page. See pages.zig for the pages,
//! model.zig for the rules, card.zig for the card, and DESIGN.md.

const std = @import("std");
const model = @import("model.zig");
const pages_mod = @import("pages.zig");
const card = @import("card.zig");
const png = @import("png.zig");
const reference = @import("reference.zig");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = std.Io.Dir;

test {
    _ = model;
    _ = png;
    _ = @import("html.zig");
    _ = @import("chart.zig");
    _ = pages_mod;
    _ = card;
    _ = reference;
}

pub const Revision = pages_mod.Revision;
const Generation = pages_mod.Generation;

pub const default_site_url = "https://zig-whatwg.github.io/crane/";

pub const Inputs = struct {
    state_json: []const u8,
    history_json: []const u8,
    worklist_text: []const u8,
    worklist_name: []const u8 = "tests/wpt_0_1_worklist.txt",
    /// wpt-results/: journals (to locate each record's run) and streams.
    results: Dir,
    /// tools/wpt_site/assets/ (the stylesheet and faces), copied verbatim;
    /// null writes the pages and card only.
    assets: ?Dir,
    wpt: Revision = .{},
    /// Where the site is published, with a trailing slash: the social tags
    /// need absolute URLs.
    site_url: []const u8 = default_site_url,
    /// The Crane commits between consecutive generations (main asks git;
    /// see rangePairs). A generation with none shows its head alone.
    ranges: []const Range = &.{},
    /// tools/wpt_gate_exemptions.txt (model.parseExemptions); "" exempts nothing.
    exemptions_text: []const u8 = "",
    /// Set when the exemptions are invalid (generate then fails with
    /// error.InvalidExemption): where, and why.
    exemption_diag: ?*model.ExemptionDiag = null,
    /// A reference run's reference.json: another engine's results on the same
    /// worklist (reference.zig), shown beside Crane's and never counted as
    /// Crane's. Null: no comparison.
    reference_json: ?[]const u8 = null,
    /// Set when the reference is invalid (generate then fails with
    /// error.InvalidReference): why.
    reference_diag: ?*reference.Diag = null,
};

/// The Crane commits from one generation's head to the next's:
/// `git log --first-parent since..head`.
pub const Range = struct {
    since: []const u8,
    head: []const u8,
    commits: u32,
    /// The branches merged among them, oldest first ("lane/serializable").
    landed: []const []const u8,
};

pub const RangePair = struct { since: []const u8, head: []const u8 };

fn knownHead(head: []const u8) bool {
    return head.len > 0 and !std.mem.eql(u8, head, "?");
}

/// The ranges to ask git for: each generation with a recorded head, paired
/// with the previous generation that has one. A generation measured at the
/// same commit as the one before it pairs with it too (no commits).
pub fn rangePairs(arena: Allocator, history_json: []const u8) ![]const RangePair {
    const history = try std.json.parseFromSliceLeaky(History, arena, history_json, parse_options);
    var pairs: std.ArrayList(RangePair) = .empty;
    var prev: ?[]const u8 = null;
    for (history.generations) |g| {
        if (!knownHead(g.head)) continue;
        if (prev) |p| try pairs.append(arena, .{ .since = p, .head = g.head });
        prev = g.head;
    }
    return pairs.items;
}

/// The branch a merge commit's subject names: "Merge lane/x (sha): ..." and
/// git's own "Merge branch 'x'" / "Merge remote-tracking branch 'x'".
pub fn mergeName(subject: []const u8) ?[]const u8 {
    const prefix = "Merge ";
    if (!std.mem.startsWith(u8, subject, prefix)) return null;
    var rest = subject[prefix.len..];
    for ([_][]const u8{ "remote-tracking branch ", "branch " }) |p| {
        if (std.mem.startsWith(u8, rest, p)) {
            rest = rest[p.len..];
            break;
        }
    }
    if (rest.len > 0 and rest[0] == '\'') {
        const end = std.mem.indexOfScalar(u8, rest[1..], '\'') orelse return null;
        return if (end == 0) null else rest[1 .. 1 + end];
    }
    const end = std.mem.indexOfAny(u8, rest, " (:") orelse rest.len;
    return if (end == 0) null else rest[0..end];
}

/// A Range from `git log --first-parent --format=%H%x09%P%x09%s since..head`
/// (newest first): every line a commit, a line with two parents a merge.
pub fn parseRange(arena: Allocator, since: []const u8, head: []const u8, log: []const u8) !Range {
    var commits: u32 = 0;
    var landed: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, log, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        commits += 1;
        var fields = std.mem.splitScalar(u8, line, '\t');
        const hash = fields.next() orelse continue;
        const parents = fields.next() orelse continue;
        const subject = fields.rest();
        if (std.mem.indexOfScalar(u8, std.mem.trim(u8, parents, " "), ' ') == null) continue;
        try landed.append(arena, mergeName(subject) orelse hash[0..@min(hash.len, 10)]);
    }
    std.mem.reverse([]const u8, landed.items);
    return .{ .since = since, .head = head, .commits = commits, .landed = landed.items };
}

pub const Summary = struct {
    files: usize = 0,
    detail_files: usize = 0,
    dir_pages: usize = 0,
    file_pages: usize = 0,
    written: usize = 0,
    unchanged: usize = 0,
    removed: usize = 0,
    /// Every file the site holds, and their bytes.
    outputs: usize = 0,
    bytes: u64 = 0,
    largest: u64 = 0,
    largest_buf: [256]u8 = undefined,
    largest_len: usize = 0,
    generation: u64 = 0,
    head_buf: [40]u8 = undefined,
    head_len: usize = 0,
    /// State records of another engine, and stream lines of one: a reference
    /// run's results where Crane's are read. Refused, never shown as Crane's.
    refused_records: usize = 0,
    refused_stream_lines: usize = 0,
    /// Worklist files with a result in the reference run.
    reference_files: usize = 0,

    /// The Crane commit the latest generation was recorded at.
    pub fn head(s: *const Summary) []const u8 {
        return s.head_buf[0..s.head_len];
    }

    pub fn largestPath(s: *const Summary) []const u8 {
        return s.largest_buf[0..s.largest_len];
    }
};

// ============================================================================
// Inputs
// ============================================================================

/// One record of tmp/wpt-progress-state.json: the latest journal line for a
/// test file, plus where it came from (`_journal`, `_mtime`: the journal's
/// basename and mtime, which tools/wpt_progress.py adds).
const Record = struct {
    /// Absent on every line Crane's runner writes; a reference run's records
    /// carry theirs (reference.isCrane).
    engine: ?[]const u8 = null,
    status: []const u8 = "ERROR",
    passed: u64 = 0,
    failed: u64 = 0,
    timed_out: u64 = 0,
    notrun: u64 = 0,
    message: ?[]const u8 = null,
    _journal: []const u8 = "",
    _mtime: f64 = 0,

    fn counts(r: Record) model.Counts {
        return .{ .passed = r.passed, .failed = r.failed, .timed_out = r.timed_out, .notrun = r.notrun };
    }
};

const History = struct {
    generations: []const Generation = &.{},
};

const parse_options: std.json.ParseOptions = .{ .ignore_unknown_fields = true };

fn parseWorklist(arena: Allocator, text: []const u8) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        try list.append(arena, line);
    }
    std.mem.sort([]const u8, list.items, {}, lessStr);
    // A worklist naming a path twice is still one file.
    var n: usize = 0;
    for (list.items) |p| {
        if (n > 0 and std.mem.eql(u8, list.items[n - 1], p)) continue;
        list.items[n] = p;
        n += 1;
    }
    return list.items[0..n];
}

fn lessStr(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

// ============================================================================
// Runs: which journal each record came from
// ============================================================================

const Journal = struct {
    /// Relative to wpt-results/: `sweep-x/journal.jsonl` or `journal.shard0.jsonl`.
    rel: []const u8,
    /// The directory under wpt-results/, "" at the top level.
    label: []const u8,
    basename: []const u8,
    mtime: f64,
};

/// Every journal the progress report reads: wpt-results/*.jsonl and
/// wpt-results/*/*.jsonl, one directory deep, less the result streams.
/// wpt-results/reference/ holds reference runs, never Crane's journals: it is
/// not a run.
fn listJournals(arena: Allocator, io: Io, results: Dir) ![]Journal {
    var out: std.ArrayList(Journal) = .empty;
    try scanJournals(arena, io, results, "", &out);
    var it = results.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .directory) continue;
        if (std.mem.eql(u8, e.name, reference.dir_name)) continue;
        var sub = results.openDir(io, e.name, .{ .iterate = true }) catch continue;
        defer sub.close(io);
        try scanJournals(arena, io, sub, try arena.dupe(u8, e.name), &out);
    }
    std.mem.sort(Journal, out.items, {}, struct {
        fn lt(_: void, a: Journal, b: Journal) bool {
            return std.mem.order(u8, a.rel, b.rel) == .lt;
        }
    }.lt);
    return out.items;
}

fn scanJournals(arena: Allocator, io: Io, dir: Dir, label: []const u8, out: *std.ArrayList(Journal)) !void {
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .file) continue;
        if (!std.mem.endsWith(u8, e.name, ".jsonl") or std.mem.endsWith(u8, e.name, ".wptreport.jsonl")) continue;
        const st = dir.statFile(io, e.name, .{}) catch continue;
        const base = try arena.dupe(u8, e.name);
        try out.append(arena, .{
            .rel = if (label.len == 0) base else try std.fmt.allocPrint(arena, "{s}/{s}", .{ label, base }),
            .label = label,
            .basename = base,
            .mtime = @as(f64, @floatFromInt(st.mtime.nanoseconds)) / 1e9,
        });
    }
}

/// The journal a record came from: same basename, same mtime (the state
/// file keeps python's float `os.path.getmtime`; a millisecond is slack for
/// its rounding). Null when that journal has since been overwritten.
fn locate(journals: []const Journal, rec: Record) ?usize {
    for (journals, 0..) |j, i| {
        if (std.mem.eql(u8, j.basename, rec._journal) and @abs(j.mtime - rec._mtime) < 0.001) return i;
    }
    return null;
}

fn runId(arena: Allocator, journals: []const Journal, located: ?usize, rec: Record) ![]const u8 {
    if (located) |i| {
        const j = journals[i];
        const stem = j.basename[0 .. j.basename.len - ".jsonl".len];
        if (j.label.len == 0) return stem;
        if (std.mem.eql(u8, j.basename, "journal.jsonl")) return j.label;
        return std.fmt.allocPrint(arena, "{s}/{s}", .{ j.label, stem });
    }
    // Overwritten since: a name that is stable for this record and nothing else.
    var h = std.hash.Wyhash.init(0);
    h.update(rec._journal);
    h.update(std.mem.asBytes(&rec._mtime));
    return std.fmt.allocPrint(arena, "unlocated-{x:0>8}", .{@as(u32, @truncate(h.final()))});
}

// ============================================================================
// Result streams: per-subtest detail
// ============================================================================

const Line = struct { url: []const u8, bytes: []const u8 };

/// Per-source stream lines, for sources whose record came from the journal
/// that stream belongs to (`X.jsonl` streams to `X.wptreport.jsonl` beside
/// it). A stream from any other run would describe a different result than
/// the counts shown, so it is not used.
fn collectStreams(
    arena: Allocator,
    io: Io,
    results: Dir,
    journals: []const Journal,
    used: []const bool,
    known: *const std.StringHashMapUnmanaged(void),
    rec_journal: *const std.StringHashMapUnmanaged(usize),
    refused: *usize,
) !std.StringArrayHashMapUnmanaged(std.ArrayList(Line)) {
    var by_source: std.StringArrayHashMapUnmanaged(std.ArrayList(Line)) = .empty;
    var scratch: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer scratch.deinit();
    for (journals, 0..) |j, ji| {
        if (!used[ji]) continue;
        const stem = j.rel[0 .. j.rel.len - ".jsonl".len];
        const stream_rel = try std.fmt.allocPrint(arena, "{s}.wptreport.jsonl", .{stem});
        const bytes = results.readFileAlloc(io, stream_rel, arena, .limited(1 << 34)) catch |e| switch (e) {
            error.FileNotFound => continue,
            else => return e,
        };
        var lines = std.mem.splitScalar(u8, bytes, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            if (line.len == 0) continue;
            _ = scratch.reset(.retain_capacity);
            // A line cut short by a killed child is dropped, never guessed at.
            const v = std.json.parseFromSliceLeaky(std.json.Value, scratch.allocator(), line, .{}) catch continue;
            if (v != .object) continue;
            // A reference run's line beside Crane's journal is not Crane's detail.
            if (v.object.get("engine")) |e| if (e != .string or !reference.isCrane(e.string)) {
                refused.* += 1;
                continue;
            };
            const t = v.object.get("test") orelse continue;
            if (t != .string) continue;
            const src = model.sourceForTestUrl(known, t.string) orelse continue;
            if ((rec_journal.get(src) orelse continue) != ji) continue;
            const gop = try by_source.getOrPut(arena, src);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(arena, .{ .url = try arena.dupe(u8, t.string), .bytes = line });
        }
    }
    // Per source: one line per test URL (a restarted child appends; the last
    // line is the latest result), sorted by URL.
    for (by_source.values()) |*list| {
        std.mem.sort(Line, list.items, {}, struct {
            fn lt(_: void, a: Line, b: Line) bool {
                return std.mem.order(u8, a.url, b.url) == .lt;
            }
        }.lt);
        // Stable sort keeps file order among equal URLs; keep the last of each.
        var n: usize = 0;
        for (list.items, 0..) |l, i| {
            if (i + 1 < list.items.len and std.mem.eql(u8, list.items[i + 1].url, l.url)) continue;
            list.items[n] = l;
            n += 1;
        }
        list.shrinkRetainingCapacity(n);
    }
    return by_source;
}

const max_message = 4096;

/// A failure message as the page shows it: at most `max_message` bytes, cut
/// on a UTF-8 boundary and saying so.
fn clipMessage(a: Allocator, msg: []const u8) ![]const u8 {
    if (msg.len <= max_message) return msg;
    var end: usize = max_message;
    while (end > 0 and (msg[end] & 0xC0) == 0x80) end -= 1;
    return std.fmt.allocPrint(a, "{s} [message truncated at {d} bytes]", .{ msg[0..end], max_message });
}

fn strField(o: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = o.get(key) orelse return null;
    return if (v == .string) v.string else null;
}

/// A file's stream lines as the page's runs, subtests in the harness's
/// order. Past `model.detail_limit` subtests the passing ones are counted,
/// not listed.
fn parseDetail(a: Allocator, lines: []const Line) ![]pages_mod.SubtestRun {
    var parsed = try a.alloc(std.json.ObjectMap, lines.len);
    var total: usize = 0;
    for (lines, 0..) |l, i| {
        const v = try std.json.parseFromSliceLeaky(std.json.Value, a, l.bytes, .{});
        parsed[i] = v.object;
        if (v.object.get("subtests")) |s| {
            if (s == .array) total += s.array.items.len;
        }
    }
    const keep_passing = model.keepsPassing(total);
    var runs = try a.alloc(pages_mod.SubtestRun, lines.len);
    for (parsed, lines, 0..) |o, l, i| {
        const subs: []const std.json.Value = if (o.get("subtests")) |s| (if (s == .array) s.array.items else &.{}) else &.{};
        var list: std.ArrayList(pages_mod.Subtest) = .empty;
        var pass: u64 = 0;
        for (subs) |sub| {
            if (sub != .object) continue;
            const st = strField(sub.object, "status") orelse "";
            const is_pass = std.mem.eql(u8, st, "PASS");
            if (is_pass) pass += 1;
            if (!keep_passing and is_pass) continue;
            try list.append(a, .{
                .name = strField(sub.object, "name") orelse "",
                .status = st,
                .message = if (strField(sub.object, "message")) |m| try clipMessage(a, m) else null,
            });
        }
        runs[i] = .{
            .test_url = l.url,
            .status = strField(o, "status") orelse "ERROR",
            .message = if (strField(o, "message")) |m| try clipMessage(a, m) else null,
            .subtests = list.items,
            .total = subs.len,
            .pass = pass,
            .passing_omitted = if (keep_passing) 0 else pass,
        };
    }
    return runs;
}

// ============================================================================
// Output
// ============================================================================

const Output = struct {
    gpa: Allocator,
    io: Io,
    dir: Dir,
    written_paths: std.StringHashMapUnmanaged(void) = .empty,
    arena: Allocator,
    summary: *Summary,

    /// Write `bytes` at `rel` unless the file already holds exactly them.
    fn put(o: *Output, rel: []const u8, bytes: []const u8) !void {
        try o.written_paths.put(o.arena, try o.arena.dupe(u8, rel), {});
        o.summary.outputs += 1;
        o.summary.bytes += bytes.len;
        if (bytes.len > o.summary.largest) {
            o.summary.largest = bytes.len;
            o.summary.largest_len = @min(rel.len, o.summary.largest_buf.len);
            @memcpy(o.summary.largest_buf[0..o.summary.largest_len], rel[0..o.summary.largest_len]);
        }
        if (o.dir.readFileAlloc(o.io, rel, o.gpa, .limited(bytes.len + 1))) |old| {
            defer o.gpa.free(old);
            if (std.mem.eql(u8, old, bytes)) {
                o.summary.unchanged += 1;
                return;
            }
        } else |_| {}
        if (std.fs.path.dirname(rel)) |d| try o.dir.createDirPath(o.io, d);
        try o.dir.writeFile(o.io, .{ .sub_path = rel, .data = bytes });
        o.summary.written += 1;
    }

    /// Remove every file this run did not write, and the directories left
    /// empty. The top-level `.git` (a worktree's pointer file or a checkout)
    /// is never touched.
    fn prune(o: *Output) !void {
        var stale: std.ArrayList([]const u8) = .empty;
        var dirs: std.ArrayList([]const u8) = .empty;
        var walker = try o.dir.walkSelectively(o.gpa);
        defer walker.deinit();
        while (try walker.next(o.io)) |e| {
            if (e.depth() == 1 and std.mem.eql(u8, e.basename, ".git")) continue;
            if (e.kind == .directory) {
                try dirs.append(o.arena, try o.arena.dupe(u8, e.path));
                try walker.enter(o.io, e);
                continue;
            }
            if (!o.written_paths.contains(e.path)) try stale.append(o.arena, try o.arena.dupe(u8, e.path));
        }
        for (stale.items) |p| {
            try o.dir.deleteFile(o.io, p);
            o.summary.removed += 1;
        }
        // Deepest first, so a parent empties after its children.
        std.mem.sort([]const u8, dirs.items, {}, struct {
            fn lt(_: void, a: []const u8, b: []const u8) bool {
                return a.len > b.len;
            }
        }.lt);
        for (dirs.items) |d| o.dir.deleteDir(o.io, d) catch {};
    }
};

fn copyAssets(o: *Output, assets: Dir) !void {
    var walker = try assets.walk(o.gpa);
    defer walker.deinit();
    var paths: std.ArrayList([]const u8) = .empty;
    while (try walker.next(o.io)) |e| {
        if (e.kind != .file) continue;
        if (e.basename[0] == '.') continue;
        try paths.append(o.arena, try o.arena.dupe(u8, e.path));
    }
    std.mem.sort([]const u8, paths.items, {}, lessStr);
    for (paths.items) |p| {
        const bytes = try assets.readFileAlloc(o.io, p, o.gpa, .limited(1 << 27));
        defer o.gpa.free(bytes);
        try o.put(p, bytes);
    }
}

// ============================================================================
// The tree
// ============================================================================

/// "dom/nodes/x.html" -> "dom/nodes/"; "dom/x.html" -> "dom/".
fn parentDir(path: []const u8) []const u8 {
    const trimmed = if (std.mem.endsWith(u8, path, "/")) path[0 .. path.len - 1] else path;
    const i = std.mem.lastIndexOfScalar(u8, trimmed, '/') orelse return "";
    return path[0 .. i + 1];
}

const DirBuild = struct {
    totals: model.Totals = .{},
    /// The reference run's, over the same files (a file it lacks is unrun).
    ref_totals: model.Totals = .{},
    dirs: std.ArrayList([]const u8) = .empty,
    files: std.ArrayList(usize) = .empty,
};

/// paths.json: every directory ("dom/nodes/") and test file of the tree,
/// sorted, for the search site.js offers. It changes only when the worklist
/// does, so a regeneration that moves results leaves it alone.
fn searchPaths(arena: Allocator, dir_keys: []const []const u8, files: []const pages_mod.FileView) ![]const u8 {
    var all: std.ArrayList([]const u8) = .empty;
    for (dir_keys) |k| if (k.len > 0) try all.append(arena, k);
    for (files) |f| try all.append(arena, f.path);
    std.mem.sort([]const u8, all.items, {}, lessStr);
    var aw: Io.Writer.Allocating = .init(arena);
    try std.json.Stringify.value(all.items, .{}, &aw.writer);
    try aw.writer.writeByte('\n');
    return aw.written();
}

// ============================================================================
// The comparison with a reference run
// ============================================================================

const CompareLists = struct {
    /// Files both ran where the reference passes more subtests, most first.
    ahead_ref: []const usize,
    /// Files both ran where Crane passes more, most first.
    ahead_crane: []const usize,
    /// Files only the reference ran, and only Crane.
    only_ref: []const usize,
    only_crane: []const usize,
};

fn passDiff(a: model.Counts, b: model.Counts) u64 {
    return a.passed -| b.passed;
}

fn compareLists(arena: Allocator, files: []const pages_mod.FileView) !CompareLists {
    var ahead_ref: std.ArrayList(usize) = .empty;
    var ahead_crane: std.ArrayList(usize) = .empty;
    var only_ref: std.ArrayList(usize) = .empty;
    var only_crane: std.ArrayList(usize) = .empty;
    for (files, 0..) |f, i| {
        const rv = f.ref orelse {
            if (f.status != null) try only_crane.append(arena, i);
            continue;
        };
        if (f.status == null) {
            try only_ref.append(arena, i);
            continue;
        }
        if (rv.counts.passed > f.counts.passed) try ahead_ref.append(arena, i);
        if (f.counts.passed > rv.counts.passed) try ahead_crane.append(arena, i);
    }
    const ByRef = struct {
        files: []const pages_mod.FileView,
        fn lt(ctx: @This(), a: usize, b: usize) bool {
            const da = passDiff(ctx.files[a].ref.?.counts, ctx.files[a].counts);
            const db = passDiff(ctx.files[b].ref.?.counts, ctx.files[b].counts);
            if (da != db) return da > db;
            return std.mem.order(u8, ctx.files[a].path, ctx.files[b].path) == .lt;
        }
    };
    const ByCrane = struct {
        files: []const pages_mod.FileView,
        fn lt(ctx: @This(), a: usize, b: usize) bool {
            const da = passDiff(ctx.files[a].counts, ctx.files[a].ref.?.counts);
            const db = passDiff(ctx.files[b].counts, ctx.files[b].ref.?.counts);
            if (da != db) return da > db;
            return std.mem.order(u8, ctx.files[a].path, ctx.files[b].path) == .lt;
        }
    };
    std.mem.sort(usize, ahead_ref.items, ByRef{ .files = files }, ByRef.lt);
    std.mem.sort(usize, ahead_crane.items, ByCrane{ .files = files }, ByCrane.lt);
    return .{ .ahead_ref = ahead_ref.items, .ahead_crane = ahead_crane.items, .only_ref = only_ref.items, .only_crane = only_crane.items };
}

// ============================================================================
// generate
// ============================================================================

pub fn generate(gpa: Allocator, io: Io, in: Inputs, out: Dir) !Summary {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var summary: Summary = .{};

    const state = try std.json.parseFromSliceLeaky(std.json.ArrayHashMap(Record), arena, in.state_json, parse_options);
    // A record of another engine in the state is a reference run's result where
    // Crane's are kept: refused, and its file reads as Crane has it otherwise.
    for (state.map.values()) |r| {
        if (!reference.isCrane(r.engine)) summary.refused_records += 1;
    }
    var local_rdiag: reference.Diag = .{};
    const ref: ?reference.Reference = if (in.reference_json) |j|
        try reference.parse(arena, j, in.reference_diag orelse &local_rdiag)
    else
        null;
    const history = try std.json.parseFromSliceLeaky(History, arena, in.history_json, parse_options);
    const generations = try arena.dupe(Generation, history.generations);
    {
        var prev: ?*const Generation = null;
        for (generations) |*g| {
            if (!knownHead(g.head)) continue;
            if (prev) |p| for (in.ranges) |r| {
                if (!std.mem.eql(u8, r.since, p.head) or !std.mem.eql(u8, r.head, g.head)) continue;
                g.since = r.since;
                g.since_n = p.n;
                g.commits = r.commits;
                g.landed = r.landed;
                break;
            };
            prev = g;
        }
    }
    const worklist = try parseWorklist(arena, in.worklist_text);
    const journals = try listJournals(arena, io, in.results);

    var known: std.StringHashMapUnmanaged(void) = .empty;
    for (worklist) |p| try known.put(arena, p, {});

    // The gate's exemptions: invalid ones stop the site, never exempt silently.
    var local_diag: model.ExemptionDiag = .{};
    const diag = in.exemption_diag orelse &local_diag;
    const exemptions = try model.parseExemptions(arena, in.exemptions_text, diag);
    try model.checkExemptionPaths(exemptions, &known, diag);
    var exempt_of: std.StringHashMapUnmanaged(*const model.Exemption) = .empty;
    for (exemptions) |*e| try exempt_of.put(arena, e.path, e);

    // Each in-scope record's run.
    var files = try arena.alloc(pages_mod.FileView, worklist.len);
    var used = try arena.alloc(bool, journals.len);
    @memset(used, false);
    var rec_journal: std.StringHashMapUnmanaged(usize) = .empty;
    var runs: std.StringArrayHashMapUnmanaged(pages_mod.RunInfo) = .empty;
    for (worklist, 0..) |p, i| {
        const rec: ?Record = if (state.map.get(p)) |r| (if (reference.isCrane(r.engine)) r else null) else null;
        const c: model.Counts = if (rec) |r| r.counts() else .{};
        files[i] = .{
            .path = p,
            .status = if (rec) |r| r.status else null,
            .counts = c,
            .message = if (rec) |r| (if (r.message) |m| try clipMessage(arena, m) else null) else null,
            .gate = model.gateOf(if (rec) |r| r.status else null, c),
            .run = null,
            .has_detail = false,
            .exemption = exempt_of.get(p),
        };
        if (files[i].exemption != null) files[i].gate = files[i].gate.exempted();
        if (ref) |rf| if (rf.files.map.get(p)) |rr| {
            var g = model.gateOf(rr.status, rr.counts());
            if (files[i].exemption != null) g = g.exempted();
            files[i].ref = .{ .status = rr.status, .counts = rr.counts(), .gate = g, .urls = rr.urls, .missing_urls = rr.missing_urls };
            summary.reference_files += 1;
        };
        const r = rec orelse continue;
        const located = locate(journals, r);
        if (located) |ji| {
            used[ji] = true;
            try rec_journal.put(arena, p, ji);
        }
        const id = try runId(arena, journals, located, r);
        files[i].run = id;
        const gop = try runs.getOrPut(arena, id);
        if (!gop.found_existing) {
            var buf: [20]u8 = undefined;
            const secs: u64 = if (r._mtime > 0) @intFromFloat(@floor(r._mtime)) else 0;
            gop.value_ptr.* = .{
                .id = id,
                .commit = if (located) |ji| model.labelCommit(journals[ji].label) else null,
                .date = try arena.dupe(u8, model.isoUtc(&buf, secs)),
                .journal = if (located) |ji| journals[ji].rel else r._journal,
            };
        }
        gop.value_ptr.files += 1;
    }
    // Runs in id order, so the page lists them the same way every time.
    runs.sort(struct {
        keys: []const []const u8,
        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return std.mem.order(u8, ctx.keys[a], ctx.keys[b]) == .lt;
        }
    }{ .keys = runs.keys() });

    var streams = try collectStreams(arena, io, in.results, journals, used, &known, &rec_journal, &summary.refused_stream_lines);
    for (files) |*f| {
        const lines = streams.getPtr(f.path) orelse continue;
        if (lines.items.len == 0) continue;
        f.has_detail = true;
        summary.detail_files += 1;
    }

    // Every ancestor directory of every file.
    var builds: std.StringArrayHashMapUnmanaged(DirBuild) = .empty;
    try builds.put(arena, "", .{});
    for (files, 0..) |f, i| {
        var child: []const u8 = f.path;
        var dir = parentDir(f.path);
        var is_file = true;
        while (true) {
            const gop = try builds.getOrPut(arena, dir);
            if (!gop.found_existing) gop.value_ptr.* = .{};
            gop.value_ptr.totals.add(f.gate, f.counts);
            if (f.ref) |rv| gop.value_ptr.ref_totals.add(rv.gate, rv.counts) else gop.value_ptr.ref_totals.add(.unrun, .{});
            if (is_file) {
                try gop.value_ptr.files.append(arena, i);
            } else {
                const list = &gop.value_ptr.dirs;
                var seen = false;
                for (list.items) |d| if (std.mem.eql(u8, d, child)) {
                    seen = true;
                    break;
                };
                if (!seen) try list.append(arena, child);
            }
            if (dir.len == 0) break;
            child = dir;
            dir = parentDir(dir);
            is_file = false;
        }
    }
    var dirs: std.StringArrayHashMapUnmanaged(pages_mod.DirView) = .empty;
    const dir_keys = try arena.dupe([]const u8, builds.keys());
    std.mem.sort([]const u8, dir_keys, {}, lessStr);
    for (dir_keys) |k| {
        const b = builds.getPtr(k).?;
        std.mem.sort([]const u8, b.dirs.items, {}, lessStr);
        // Files were appended in worklist (sorted) order already.
        try dirs.put(arena, k, .{ .path = k, .totals = b.totals, .ref_totals = b.ref_totals, .dirs = b.dirs.items, .files = b.files.items });
    }
    const root_totals = dirs.getPtr("").?.totals;

    // The card, and its cache-busting reference: it changes when the numbers do.
    const card_figures: card.Figures = .{
        .pass = root_totals.sub_pass,
        .reported = root_totals.subReported(),
        .failed = root_totals.sub_fail,
        .timed_out = root_totals.sub_timeout,
        .notrun = root_totals.sub_notrun,
        .files = root_totals.files,
        .blocking = root_totals.blocking(),
    };
    const card_png = try card.render(gpa, card_figures);
    defer gpa.free(card_png);
    const card_ref = try std.fmt.allocPrint(arena, "card.png?v={x:0>8}", .{@as(u32, @truncate(std.hash.Wyhash.hash(0, card_png)))});

    // The files the two engines differ on, for the comparison page.
    const cmp = try compareLists(arena, files);
    const ref_ptr: ?*const reference.Reference = if (ref) |r| blk: {
        const p = try arena.create(reference.Reference);
        p.* = r;
        break :blk p;
    } else null;

    const site: pages_mod.Site = .{
        .files = files,
        .dirs = &dirs,
        .suites = dirs.getPtr("").?.dirs,
        .runs = &runs,
        .history = generations,
        .wpt = in.wpt,
        .worklist_name = in.worklist_name,
        .detail_files = summary.detail_files,
        .site_url = in.site_url,
        .card_ref = card_ref,
        .exemptions = exemptions,
        .reference = ref_ptr,
        .ahead_ref = cmp.ahead_ref,
        .ahead_crane = cmp.ahead_crane,
        .only_ref = cmp.only_ref,
        .only_crane = cmp.only_crane,
    };

    var o: Output = .{ .gpa = gpa, .io = io, .dir = out, .arena = arena, .summary = &summary };
    if (in.assets) |a| try copyAssets(&o, a);
    try o.put(".nojekyll", "");
    try o.put("card.png", card_png);
    try o.put("paths.json", try searchPaths(arena, dir_keys, files));

    var aw: Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try pages_mod.writeIndex(&aw.writer, &site);
    try o.put("index.html", aw.written());

    if (site.reference) |r| {
        aw.clearRetainingCapacity();
        try pages_mod.writeComparePage(&aw.writer, &site);
        try o.put(try std.fmt.allocPrint(arena, "{s}.html", .{r.engine}), aw.written());
    }

    for (dir_keys) |k| {
        if (k.len == 0) continue;
        aw.clearRetainingCapacity();
        try pages_mod.writeDirPage(&aw.writer, &site, dirs.getPtr(k).?);
        try o.put(try std.fmt.allocPrint(arena, "{s}index.html", .{k}), aw.written());
        summary.dir_pages += 1;
    }

    var detail_arena: std.heap.ArenaAllocator = .init(gpa);
    defer detail_arena.deinit();
    for (files) |*f| {
        _ = detail_arena.reset(.retain_capacity);
        const detail: []const pages_mod.SubtestRun = if (streams.getPtr(f.path)) |lines|
            try parseDetail(detail_arena.allocator(), lines.items)
        else
            &.{};
        aw.clearRetainingCapacity();
        try pages_mod.writeFilePage(&aw.writer, &site, f, detail);
        try o.put(try std.fmt.allocPrint(arena, "{s}/index.html", .{f.path}), aw.written());
        summary.file_pages += 1;
    }

    try o.prune();
    const last = site.latest();
    summary.files = worklist.len;
    summary.generation = last.n;
    summary.head_len = @min(last.head.len, summary.head_buf.len);
    @memcpy(summary.head_buf[0..summary.head_len], last.head[0..summary.head_len]);
    return summary;
}

// ============================================================================
// main
// ============================================================================

fn usage() noreturn {
    std.debug.print(
        \\usage: wpt_site [--state=<json>] [--history=<json>] [--worklist=<txt>] [--results=<dir>]
        \\                [--assets=<dir>] [--out=<dir>] [--wpt-root=<dir>] [--site-url=<url>]
        \\                [--exemptions=<txt>] [--reference=<reference.json>|--no-reference] [--no-commit]
        \\       wpt_site import-reference --engine=<chrome|firefox|safari> --report=<wptreport.json>
        \\                --manifest=<MANIFEST.json> --worklist=<txt> --meta=<run.json> --out=<dir>
        \\
        \\Defaults are the repository's: tmp/wpt-progress-state.json, wpt-results/progress-history.json,
        \\tests/wpt_0_1_worklist.txt, wpt-results/, tools/wpt_site/assets/, wpt-results/site/, tests/wpt/,
        \\https://zig-whatwg.github.io/crane/ (the absolute URL the social tags name),
        \\tools/wpt_gate_exemptions.txt, and the newest Chrome run under wpt-results/reference/.
        \\When --out is a git worktree on the gh-pages branch and anything changed, the output is committed
        \\there ("results: generation <n>, Crane <sha>"). Nothing is ever pushed.
        \\import-reference joins another engine's wptreport to the worklist through the manifest and
        \\writes <out>/reference.json (tools/wpt_site/reference.zig).
        \\
    , .{});
    std.process.exit(2);
}

fn isHex40(s: []const u8) bool {
    if (s.len != 40) return false;
    for (s) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    return true;
}

/// Run `argv` in `cwd`; its trimmed stdout, or null when it fails.
fn capture(arena: Allocator, io: Io, cwd: []const u8, argv: []const []const u8) ?[]const u8 {
    const r = std.process.run(arena, io, .{ .argv = argv, .cwd = .{ .path = cwd } }) catch return null;
    if (r.term != .exited or r.term.exited != 0) return null;
    return std.mem.trim(u8, r.stdout, &std.ascii.whitespace);
}

/// The WPT revision the tree is at: the upstream commit the fork's snapshot
/// records, else the fork's own commit, else unknown.
fn detectRevision(arena: Allocator, io: Io, wpt_root: []const u8) Revision {
    const file = std.fmt.allocPrint(arena, "{s}/.crane-upstream-revision", .{wpt_root}) catch return .{};
    if (Dir.cwd().readFileAlloc(io, file, arena, .limited(4096))) |bytes| {
        const t = std.mem.trim(u8, bytes, &std.ascii.whitespace);
        if (isHex40(t)) return .{ .sha = t, .kind = "upstream" };
    } else |_| {}
    if (capture(arena, io, wpt_root, &.{ "git", "rev-parse", "HEAD" })) |sha| {
        if (isHex40(sha)) return .{ .sha = sha, .kind = "fork" };
    }
    return .{};
}

/// Commit `out` on gh-pages when it is that branch's worktree and something
/// changed. Never pushes, never creates the branch.
fn commitSite(arena: Allocator, io: Io, out: []const u8, summary: Summary) !void {
    Dir.cwd().access(io, try std.fmt.allocPrint(arena, "{s}/.git", .{out}), .{}) catch {
        std.debug.print("wpt-site: {s} is not a git worktree; nothing committed\n", .{out});
        return;
    };
    const top = capture(arena, io, out, &.{ "git", "rev-parse", "--show-toplevel" }) orelse return error.GitFailed;
    const real_out = try Dir.cwd().realPathFileAlloc(io, out, arena);
    const real_top = try Dir.cwd().realPathFileAlloc(io, top, arena);
    if (!std.mem.eql(u8, real_out, real_top)) {
        std.debug.print("wpt-site: {s} is inside another checkout ({s}), not a worktree of its own; nothing committed\n", .{ out, top });
        return;
    }
    const branch = capture(arena, io, out, &.{ "git", "rev-parse", "--abbrev-ref", "HEAD" }) orelse return error.GitFailed;
    if (!std.mem.eql(u8, branch, "gh-pages")) {
        std.debug.print("wpt-site: {s} is on branch '{s}', not gh-pages; nothing committed\n", .{ out, branch });
        return;
    }
    // --force: the output holds only what this generator wrote, so no ignore rule may
    // decide what ships. The repository's shared .git/info/exclude applies to every
    // worktree, and its `/data` line (for agent worktrees' data link) silently kept the
    // whole data/ directory out of the first published site (2026-09-30).
    _ = capture(arena, io, out, &.{ "git", "add", "-A", "--force", "." }) orelse return error.GitFailed;
    // `diff --cached --quiet` exits 0 when nothing is staged.
    if (capture(arena, io, out, &.{ "git", "diff", "--cached", "--quiet" }) != null) {
        std.debug.print("wpt-site: gh-pages already current; nothing committed\n", .{});
        return;
    }
    const msg = try std.fmt.allocPrint(arena, "results: generation {d}, Crane {s}", .{ summary.generation, summary.head() });
    _ = capture(arena, io, out, &.{ "git", "commit", "-q", "-m", msg }) orelse return error.GitFailed;
    std.debug.print("wpt-site: committed on gh-pages: {s}\n", .{msg});
}

/// `import-reference`: write <out>/reference.json from a reference run's
/// wptreport (reference.import).
fn importReference(arena: Allocator, io: Io, args: anytype) !void {
    var engine: []const u8 = "";
    var report_path: []const u8 = "";
    var manifest_path: []const u8 = "";
    var worklist_path: []const u8 = "";
    var meta_path: []const u8 = "";
    var out_path: []const u8 = "";
    while (args.next()) |a| {
        const eq = std.mem.indexOfScalar(u8, a, '=') orelse usage();
        const key = a[0..eq];
        const val = a[eq + 1 ..];
        if (std.mem.eql(u8, key, "--engine")) engine = val else if (std.mem.eql(u8, key, "--report")) report_path = val else if (std.mem.eql(u8, key, "--manifest")) manifest_path = val else if (std.mem.eql(u8, key, "--worklist")) worklist_path = val else if (std.mem.eql(u8, key, "--meta")) meta_path = val else if (std.mem.eql(u8, key, "--out")) out_path = val else usage();
    }
    for ([_][]const u8{ engine, report_path, manifest_path, worklist_path, meta_path, out_path }) |v| if (v.len == 0) usage();
    const cwd = Dir.cwd();
    const report_bytes = try cwd.readFileAlloc(io, report_path, arena, .limited(1 << 34));
    const manifest_bytes = try cwd.readFileAlloc(io, manifest_path, arena, .limited(1 << 31));
    const worklist_text = try cwd.readFileAlloc(io, worklist_path, arena, .limited(1 << 28));
    const meta_bytes = try cwd.readFileAlloc(io, meta_path, arena, .limited(1 << 20));
    var diag: reference.Diag = .{};
    const imp = reference.import(arena, engine, report_bytes, manifest_bytes, worklist_text, meta_bytes, &diag) catch |e| switch (e) {
        error.InvalidReference => {
            std.debug.print("wpt-site import-reference: {s}\n", .{diag.message()});
            std.process.exit(1);
        },
        else => |err| return err,
    };
    var aw: Io.Writer.Allocating = .init(arena);
    try reference.write(&aw.writer, imp);
    var out = try cwd.createDirPathOpen(io, out_path, .{});
    defer out.close(io);
    try out.writeFile(io, .{ .sub_path = "reference.json", .data = aw.written() });
    const c = imp.coverage;
    std.debug.print(
        "wpt-site import-reference: {s} {s} ({s}): {d} of {d} worklist sources have a result; " ++
            "{d} of {d} test URLs reported, {d} skipped, {d} missing; {d} URLs outside the worklist and {d} outside the manifest left out; wrote {s}/reference.json\n",
        .{
            imp.engine,      imp.meta.run.browser_version, imp.meta.run.date, c.sources_reported, c.sources,
            c.urls_reported, c.urls_expected,              c.urls_skipped,    c.urls_missing,     c.urls_outside,
            c.urls_unknown,  out_path,
        },
    );
}

/// The newest reference run of `engine` under `<results>/reference/*/reference.json`
/// (by its run date), and the path it came from; null when there is none.
/// A reference.json anywhere else in `results` is never read, and said so.
fn findReference(arena: Allocator, io: Io, results: Dir, results_path: []const u8, engine: []const u8) !?struct { path: []const u8, bytes: []const u8 } {
    var it = results.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .directory or std.mem.eql(u8, e.name, reference.dir_name)) continue;
        const stray = try std.fmt.allocPrint(arena, "{s}/reference.json", .{e.name});
        _ = results.statFile(io, stray, .{}) catch continue;
        std.debug.print("wpt-site: ignored {s}/{s}: a reference run is read only from {s}/{s}/<run>/reference.json, never as Crane's\n", .{ results_path, stray, results_path, reference.dir_name });
    }
    var dir = results.openDir(io, reference.dir_name, .{ .iterate = true }) catch return null;
    defer dir.close(io);
    var best: ?struct { path: []const u8, bytes: []const u8, date: []const u8 } = null;
    var dit = dir.iterate();
    while (try dit.next(io)) |e| {
        if (e.kind != .directory) continue;
        const rel = try std.fmt.allocPrint(arena, "{s}/reference.json", .{e.name});
        const bytes = dir.readFileAlloc(io, rel, arena, .limited(1 << 30)) catch continue;
        var diag: reference.Diag = .{};
        const r = reference.parse(arena, bytes, &diag) catch {
            std.debug.print("wpt-site: ignored {s}/{s}/{s}: {s}\n", .{ results_path, reference.dir_name, rel, diag.message() });
            continue;
        };
        if (!std.mem.eql(u8, r.engine, engine)) continue;
        if (best) |b| if (std.mem.order(u8, r.run.date, b.date) != .gt) continue;
        best = .{ .path = try std.fmt.allocPrint(arena, "{s}/{s}/{s}", .{ results_path, reference.dir_name, rel }), .bytes = bytes, .date = r.run.date };
    }
    const b = best orelse return null;
    return .{ .path = b.path, .bytes = b.bytes };
}

pub fn main(init: std.process.Init) !void {
    var arena_state: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var state_path: []const u8 = "tmp/wpt-progress-state.json";
    var history_path: []const u8 = "wpt-results/progress-history.json";
    var worklist_path: []const u8 = "tests/wpt_0_1_worklist.txt";
    var results_path: []const u8 = "wpt-results";
    var assets_path: []const u8 = "tools/wpt_site/assets";
    var out_path: []const u8 = "wpt-results/site";
    var wpt_root: []const u8 = "tests/wpt";
    var site_url: []const u8 = default_site_url;
    var exemptions_path: []const u8 = "tools/wpt_gate_exemptions.txt";
    var reference_path: ?[]const u8 = null;
    var use_reference = true;
    var commit = true;

    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    var first = true;
    while (args.next()) |a| {
        if (first and std.mem.eql(u8, a, "import-reference")) return importReference(arena, io, &args);
        first = false;
        if (std.mem.eql(u8, a, "--no-reference")) {
            use_reference = false;
            continue;
        }
        if (std.mem.startsWith(u8, a, "--reference=")) {
            reference_path = a["--reference=".len..];
            continue;
        }
        const eq = std.mem.indexOfScalar(u8, a, '=');
        const key = a[0 .. eq orelse a.len];
        const val = if (eq) |i| a[i + 1 ..] else "";
        if (std.mem.eql(u8, key, "--no-commit")) commit = false else if (eq == null) usage() else if (std.mem.eql(u8, key, "--state")) state_path = val else if (std.mem.eql(u8, key, "--history")) history_path = val else if (std.mem.eql(u8, key, "--worklist")) worklist_path = val else if (std.mem.eql(u8, key, "--results")) results_path = val else if (std.mem.eql(u8, key, "--assets")) assets_path = val else if (std.mem.eql(u8, key, "--out")) out_path = val else if (std.mem.eql(u8, key, "--wpt-root")) wpt_root = val else if (std.mem.eql(u8, key, "--site-url")) site_url = val else if (std.mem.eql(u8, key, "--exemptions")) exemptions_path = val else usage();
    }

    const cwd = Dir.cwd();
    const state = try cwd.readFileAlloc(io, state_path, arena, .limited(1 << 31));
    const history = try cwd.readFileAlloc(io, history_path, arena, .limited(1 << 31));
    const worklist = try cwd.readFileAlloc(io, worklist_path, arena, .limited(1 << 28));
    const exemptions = try cwd.readFileAlloc(io, exemptions_path, arena, .limited(1 << 24));
    var results = try cwd.openDir(io, results_path, .{ .iterate = true });
    defer results.close(io);
    var assets = try cwd.openDir(io, assets_path, .{ .iterate = true });
    defer assets.close(io);
    var out = try cwd.createDirPathOpen(io, out_path, .{ .open_options = .{ .iterate = true } });
    defer out.close(io);

    // Each generation's range of Crane commits, from git (the repository is the
    // working directory). A range git cannot answer is left out: that
    // generation shows its head alone.
    var ranges: std.ArrayList(Range) = .empty;
    for (try rangePairs(arena, history)) |pair| {
        if (std.mem.eql(u8, pair.since, pair.head)) {
            try ranges.append(arena, .{ .since = pair.since, .head = pair.head, .commits = 0, .landed = &.{} });
            continue;
        }
        const span = try std.fmt.allocPrint(arena, "{s}..{s}", .{ pair.since, pair.head });
        const log = capture(arena, io, ".", &.{ "git", "log", "--first-parent", "--format=%H%x09%P%x09%s", span }) orelse continue;
        try ranges.append(arena, try parseRange(arena, pair.since, pair.head, log));
    }

    // The comparison: the newest Chrome run under wpt-results/reference/, or the one named.
    var reference_json: ?[]const u8 = null;
    if (use_reference) {
        if (reference_path) |rp| {
            reference_json = try cwd.readFileAlloc(io, rp, arena, .limited(1 << 30));
            std.debug.print("wpt-site: comparing with the reference run in {s}\n", .{rp});
        } else if (try findReference(arena, io, results, results_path, "chrome")) |found| {
            reference_json = found.bytes;
            std.debug.print("wpt-site: comparing with the reference run in {s}\n", .{found.path});
        } else std.debug.print("wpt-site: no reference run under {s}/{s}/; no comparison\n", .{ results_path, reference.dir_name });
    }

    var diag: model.ExemptionDiag = .{};
    var rdiag: reference.Diag = .{};
    const summary = generate(init.gpa, io, .{
        .reference_json = reference_json,
        .reference_diag = &rdiag,
        .exemptions_text = exemptions,
        .exemption_diag = &diag,
        .ranges = ranges.items,
        .state_json = state,
        .history_json = history,
        .worklist_text = worklist,
        .worklist_name = worklist_path,
        .results = results,
        .assets = assets,
        .wpt = detectRevision(arena, io, wpt_root),
        .site_url = site_url,
    }, out) catch |e| switch (e) {
        error.InvalidExemption => {
            if (diag.line > 0)
                std.debug.print("wpt-site: {s}:{d}: {s}\n", .{ exemptions_path, diag.line, diag.message })
            else
                std.debug.print("wpt-site: {s}: {s}: {s}\n", .{ exemptions_path, diag.path, diag.message });
            std.process.exit(1);
        },
        error.InvalidReference => {
            std.debug.print("wpt-site: the reference run is invalid: {s}\n", .{rdiag.message()});
            std.process.exit(1);
        },
        else => |err| return err,
    };
    if (summary.refused_records > 0 or summary.refused_stream_lines > 0) std.debug.print(
        "wpt-site: REFUSED {d} state records and {d} result-stream lines of another engine: a reference run is never Crane's; it belongs in {s}/{s}/<run>/\n",
        .{ summary.refused_records, summary.refused_stream_lines, results_path, reference.dir_name },
    );
    if (reference_json != null) std.debug.print("wpt-site: the reference run has a result for {d} of the worklist's files\n", .{summary.reference_files});
    std.debug.print(
        "wpt-site: generation {d} (Crane {s}): {d} test files, {d} with subtest detail; {d} directory pages, {d} file pages; " ++
            "{d} files in the site, {d} bytes (largest {s}, {d} bytes); {d} written, {d} unchanged, {d} removed, in {s}\n",
        .{
            summary.generation, summary.head(),    summary.files,   summary.detail_files,  summary.dir_pages,
            summary.file_pages, summary.outputs,   summary.bytes,   summary.largestPath(), summary.largest,
            summary.written,    summary.unchanged, summary.removed, out_path,
        },
    );
    if (commit) try commitSite(arena, io, out_path, summary);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const Fixture = struct {
    tmp: testing.TmpDir,
    results: Dir,
    journal_mtime: f64,
    other_mtime: f64,

    /// wpt-results/ with one labelled run (sweep-abc1234, a journal and its
    /// stream) and one unlabelled journal whose stream must not be used for
    /// records that came from the labelled run.
    fn init(stream: []const u8) !Fixture {
        var tmp = testing.tmpDir(.{ .iterate = true });
        errdefer tmp.cleanup();
        const io = testing.io;
        try tmp.dir.createDirPath(io, "results/sweep-abc1234");
        try tmp.dir.createDirPath(io, "results/other");
        try tmp.dir.writeFile(io, .{ .sub_path = "results/sweep-abc1234/journal.jsonl", .data = "{}\n" });
        try tmp.dir.writeFile(io, .{ .sub_path = "results/sweep-abc1234/journal.wptreport.jsonl", .data = stream });
        try tmp.dir.writeFile(io, .{ .sub_path = "results/other/journal.shard0.jsonl", .data = "{}\n" });
        try tmp.dir.writeFile(io, .{ .sub_path = "results/other/journal.shard0.wptreport.jsonl", .data =
            \\{"test":"/dom/b.html","status":"OK","message":null,"subtests":[{"name":"stale","status":"PASS","message":null}]}
            \\
        });
        const results = try tmp.dir.openDir(io, "results", .{ .iterate = true });
        const st = try results.statFile(io, "sweep-abc1234/journal.jsonl", .{});
        const st2 = try results.statFile(io, "other/journal.shard0.jsonl", .{});
        return .{
            .tmp = tmp,
            .results = results,
            .journal_mtime = @as(f64, @floatFromInt(st.mtime.nanoseconds)) / 1e9,
            .other_mtime = @as(f64, @floatFromInt(st2.mtime.nanoseconds)) / 1e9,
        };
    }

    fn deinit(f: *Fixture) void {
        f.results.close(testing.io);
        f.tmp.cleanup();
    }

    fn state(f: *Fixture, gpa: Allocator) ![]u8 {
        return std.fmt.allocPrint(gpa,
            \\{{"dom/a.html":{{"path":"dom/a.html","status":"OK","passed":2,"failed":1,"timed_out":0,"notrun":0,"_journal":"journal.jsonl","_mtime":{d}}},
            \\"dom/nodes/c.any.js":{{"path":"dom/nodes/c.any.js","status":"OK","passed":0,"failed":2,"timed_out":0,"notrun":0,"_journal":"journal.jsonl","_mtime":{d}}},
            \\"dom/b.html":{{"path":"dom/b.html","status":"TIMEOUT","passed":0,"failed":0,"timed_out":0,"notrun":0,"message":"took too long","_journal":"journal.jsonl","_mtime":{d}}},
            \\"url/u.html":{{"path":"url/u.html","status":"OK","passed":3,"failed":0,"timed_out":0,"notrun":0,"_journal":"journal.shard0.jsonl","_mtime":{d}}},
            \\"not/in/worklist.html":{{"path":"not/in/worklist.html","status":"CRASH","passed":0,"failed":0,"timed_out":0,"notrun":0,"_journal":"journal.jsonl","_mtime":{d}}}}}
        , .{ f.journal_mtime, f.journal_mtime, f.journal_mtime, f.other_mtime, f.journal_mtime });
    }
};

const fixture_history =
    \\{"gate_rule":2,"generations":[
    \\{"n":1,"at":"2026-09-19T19:55:00","head":"?","reconstructed":true,"total":5,"run":2,"unrun":3,"blocking":1,"crash":0,"timeout":1,"error":0,"clean":1,"partial":0,"sub_pass":3,"sub_fail":0,"sub_passing":3,"sub_targeted":6},
    \\{"n":2,"at":"2026-09-30T11:21:23","head":"5c8dd64da","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3,"sub_passing":5,"sub_targeted":8,"subs":{"passed":5,"failed":3,"timed_out":0,"notrun":0}}
    \\],"last_statuses":{}}
;

const fixture_history_next =
    \\{"gate_rule":2,"generations":[
    \\{"n":1,"at":"2026-09-19T19:55:00","head":"?","reconstructed":true,"total":5,"run":2,"unrun":3,"blocking":1,"crash":0,"timeout":1,"error":0,"clean":1,"partial":0,"sub_pass":3,"sub_fail":0,"sub_passing":3,"sub_targeted":6},
    \\{"n":2,"at":"2026-09-30T11:21:23","head":"5c8dd64da","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3,"sub_passing":5,"sub_targeted":8,"subs":{"passed":5,"failed":3,"timed_out":0,"notrun":0}},
    \\{"n":3,"at":"2026-10-01T09:00:00","head":"6d9ee75eb","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3,"sub_passing":5,"sub_targeted":8,"subs":{"passed":5,"failed":3,"timed_out":0,"notrun":0}}
    \\],"last_statuses":{}}
;

const fixture_worklist =
    \\# a comment
    \\dom/b.html
    \\dom/a.html
    \\dom/nodes/c.any.js
    \\url/u.html
    \\url/never.html
    \\
;

const fixture_stream =
    \\{"test":"/dom/a.html","status":"OK","message":null,"duration":5,"subtests":[{"name":"one","status":"PASS","message":null},{"name":"two <b>&","status":"FAIL","message":"assert_equals: expected 1 but got 2"},{"name":"three","status":"PASS","message":null}]}
    \\{"test":"/dom/nodes/c.any.worker.html","status":"OK","message":null,"subtests":[{"name":"w","status":"FAIL","message":"worker"}]}
    \\{"test":"/dom/nodes/c.any.html","status":"OK","message":null,"subtests":[{"name":"x","status":"FAIL","message":"window"}]}
    \\{"test":"/crane/ours.html","status":"OK","message":null,"subtests":[]}
    \\
;

fn runFixture(gpa: Allocator, f: *Fixture, out_name: []const u8, worklist: []const u8) !Summary {
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, out_name, .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    return generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = fixture_history,
        .worklist_text = worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
    }, out);
}

const fixture_wpt: Revision = .{ .sha = "50d8c16fa8219824aad90ef0ec02328e7ecbc8e5", .kind = "fork" };

fn readOut(gpa: Allocator, f: *Fixture, path: []const u8) ![]u8 {
    return f.tmp.dir.readFileAlloc(testing.io, path, gpa, .limited(1 << 24));
}

fn exists(f: *Fixture, path: []const u8) bool {
    _ = f.tmp.dir.statFile(testing.io, path, .{}) catch return false;
    return true;
}

fn expectHas(hay: []const u8, needle: []const u8) !void {
    if (std.mem.indexOf(u8, hay, needle) == null) {
        std.debug.print("\nmissing: {s}\n", .{needle});
        return error.TestExpectedSubstring;
    }
}

fn expectBefore(hay: []const u8, a: []const u8, b: []const u8) !void {
    const ia = std.mem.indexOf(u8, hay, a) orelse return error.TestExpectedSubstring;
    const ib = std.mem.indexOf(u8, hay, b) orelse return error.TestExpectedSubstring;
    try testing.expect(ia < ib);
}

test "site: index.html opens with the WPT subtest numbers, written into the markup" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    try testing.expectEqual(@as(usize, 5), s.files);
    try testing.expectEqual(@as(u64, 2), s.generation);

    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    // 2+0+0+3 passed of 3+2+0+3 reported; 3 failed; b.html TIMEOUT and
    // c.any.js NONE-PASSED block; url/never.html has not run.
    try expectHas(index, "<span class=\"hl-pass\">5</span><span class=\"hl-of\"> / 8</span>");
    try expectHas(index, "WPT subtests passing");
    try expectHas(index, "<div class=\"fail\"><dt>Failed</dt><dd>3</dd>");
    try expectHas(index, "<dt>Timed out</dt><dd>0</dd>");
    try expectHas(index, "<dt>Not run</dt><dd>0</dd>");
    try expectHas(index, "<dt>Test files</dt><dd>5</dd>");
    try expectHas(index, "<div class=\"blk\"><dt>Blocking files</dt><dd>2</dd>");
    // Numbers first: the headline, then the scope, the contents, the suites, the history.
    try expectBefore(index, "hl-pass", "id=\"status\"");
    try expectBefore(index, "id=\"status\"", "id=\"contents\"");
    try expectBefore(index, "id=\"contents\"", "<section class=\"suite\" id=\"dom\"");
    try expectBefore(index, "<section class=\"suite\" id=\"dom\"", "<section class=\"suite\" id=\"url\"");
    try expectBefore(index, "<section class=\"suite\" id=\"url\"", "id=\"history\"");
    // Each suite section opens with its own numbers: dom/ has 2 of 5.
    try expectHas(index, "<span class=\"fg-pass\">2</span><span class=\"fg-of\"> / 5</span>");
    // Its table links down to the directory and file pages.
    try expectHas(index, "<a href=\"dom/nodes/\"><span class=\"dir-no\">1.1</span>");
    try expectHas(index, "<a href=\"dom/a.html/\">");
    // The revision history: a drawn chart and a table, no script.
    try expectHas(index, "<svg class=\"chart-svg chart-wide\"");
    try expectHas(index, "<td><code>5c8dd64da</code></td>");
    // The phrase the user ruled out, and a pass percentage, are nowhere.
    try testing.expect(std.mem.indexOf(u8, index, "passing every subtest") == null);
    try testing.expect(std.mem.indexOf(u8, index, "% of subtests") == null);
}

test "site: one page per directory and per test file, mirroring the WPT tree" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    // dom/, dom/nodes/, url/ and five files.
    try testing.expectEqual(@as(usize, 3), s.dir_pages);
    try testing.expectEqual(@as(usize, 5), s.file_pages);
    for ([_][]const u8{
        "out/dom/index.html",        "out/dom/nodes/index.html",      "out/url/index.html",
        "out/dom/a.html/index.html", "out/dom/b.html/index.html",     "out/dom/nodes/c.any.js/index.html",
        "out/url/u.html/index.html", "out/url/never.html/index.html", "out/card.png",
    }) |p| if (!exists(&f, p)) {
        std.debug.print("\nmissing page {s}\n", .{p});
        return error.TestExpectedPage;
    };

    const dom = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(dom);
    try expectHas(dom, "<h1 class=\"page-title\"><span class=\"secno\">1</span><code>dom/</code></h1>");
    try expectHas(dom, "<span class=\"fg-pass\">2</span><span class=\"fg-of\"> / 5</span>");
    try expectHas(dom, "<a href=\"../dom/nodes/\"><span class=\"dir-no\">1.1</span>");
    try expectHas(dom, "<a href=\"../dom/a.html/\">");
    try expectHas(dom, "<span class=\"gate gate-timeout g-block\">TIMEOUT</span>");
    try expectHas(dom, "<span class=\"gate gate-partial\">With failures</span>");
    try expectHas(dom, "<link rel=\"stylesheet\" href=\"../site.css\">");
    // The rail marks the suite this page belongs to.
    try expectHas(dom, "<a href=\"../dom/\" aria-current=\"page\">");

    const nodes = try readOut(gpa, &f, "out/dom/nodes/index.html");
    defer gpa.free(nodes);
    try expectHas(nodes, "<li><a href=\"../../dom/\"><code>dom/</code></a></li><li aria-current=\"page\"><code>nodes/</code></li>");
    try expectHas(nodes, "<span class=\"gate gate-none-passed g-block\">NONE-PASSED</span>");

    const never = try readOut(gpa, &f, "out/url/never.html/index.html");
    defer gpa.free(never);
    try expectHas(never, "<span class=\"gate gate-unrun\">Not run</span>");
    try expectHas(never, "It has no result yet.");
    try expectHas(never, "<link rel=\"stylesheet\" href=\"../../site.css\">");
}

test "site: a test file's page lists its subtests, failures opening in place" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    // a.html and c.any.js have detail; b.html's only stream line is in a
    // stream from another run, which must not be used.
    try testing.expectEqual(@as(usize, 2), s.detail_files);

    const a = try readOut(gpa, &f, "out/dom/a.html/index.html");
    defer gpa.free(a);
    try expectHas(a, "<span class=\"fg-pass\">2</span><span class=\"fg-of\"> / 3</span>");
    try expectHas(a, "<details><summary><span class=\"mark\">FAIL</span><span class=\"sub-name\">two &lt;b&gt;&amp;</span></summary><pre class=\"msg\">assert_equals: expected 1 but got 2</pre></details>");
    try expectHas(a, "<div class=\"sub-line\"><span class=\"mark\">PASS</span><span class=\"sub-name\">one</span></div>");
    try expectHas(a, "https://github.com/zig-whatwg/wpt/blob/50d8c16fa8219824aad90ef0ec02328e7ecbc8e5/dom/a.html");
    try expectHas(a, "<code>sweep-abc1234</code>");
    try expectHas(a, "/commit/abc1234\"><code>abc1234</code></a>");
    try expectBefore(a, "\"sub-name\">one<", "\"sub-name\">two &lt;b&gt;&amp;<");
    try expectBefore(a, "\"sub-name\">two &lt;b&gt;&amp;<", "\"sub-name\">three<");

    // Two runs of c.any.js, each under its test URL, sorted.
    const c = try readOut(gpa, &f, "out/dom/nodes/c.any.js/index.html");
    defer gpa.free(c);
    try expectBefore(c, "<code>/dom/nodes/c.any.html</code>", "<code>/dom/nodes/c.any.worker.html</code>");

    const b = try readOut(gpa, &f, "out/dom/b.html/index.html");
    defer gpa.free(b);
    try expectHas(b, "No per-subtest data for this file.");
    try testing.expect(std.mem.indexOf(u8, b, "stale") == null);
    try expectHas(b, "<pre class=\"msg\">took too long</pre>");
}

test "site: a file past the detail limit keeps every non-passing subtest and counts the rest" {
    const gpa = testing.allocator;
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(gpa);
    try stream.appendSlice(gpa, "{\"test\":\"/dom/a.html\",\"status\":\"OK\",\"message\":null,\"subtests\":[");
    for (0..model.detail_limit + 10) |i| {
        if (i > 0) try stream.append(gpa, ',');
        const st = if (i % 100 == 7) "FAIL" else "PASS";
        try stream.print(gpa, "{{\"name\":\"s{d}\",\"status\":\"{s}\",\"message\":null}}", .{ i, st });
    }
    try stream.appendSlice(gpa, "]}\n");
    var f = try Fixture.init(stream.items);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);

    const a = try readOut(gpa, &f, "out/dom/a.html/index.html");
    defer gpa.free(a);
    try testing.expectEqual(@as(usize, 6), std.mem.count(u8, a, "<li class=\"sub s-fail\""));
    try testing.expectEqual(@as(usize, 0), std.mem.count(u8, a, "<li class=\"sub s-pass\""));
    try expectHas(a, "504 passing subtests are not listed");
}

test "site: no page needs script for any of its content" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    var out = try f.tmp.dir.openDir(testing.io, "out", .{ .iterate = true });
    defer out.close(testing.io);
    var walker = try out.walk(gpa);
    defer walker.deinit();
    var pages: usize = 0;
    while (try walker.next(testing.io)) |e| {
        if (e.kind != .file) continue;
        // No script comes from the generator itself (site.js is an asset), and
        // the one data file is the search's list of paths.
        try testing.expect(!std.mem.endsWith(u8, e.path, ".js"));
        if (std.mem.endsWith(u8, e.path, ".json")) try testing.expectEqualStrings("paths.json", e.path);
        if (!std.mem.endsWith(u8, e.path, ".html")) continue;
        pages += 1;
        const page = try out.readFileAlloc(testing.io, e.path, gpa, .limited(1 << 24));
        defer gpa.free(page);
        if (pages_mod.needsScript(page)) |why| {
            std.debug.print("\n{s} needs script: {s}\n", .{ e.path, why });
            return error.TestPageNeedsScript;
        }
        // Every page is a whole document with its numbers in it.
        try testing.expect(std.mem.startsWith(u8, page, "<!doctype html>\n"));
        try testing.expect(std.mem.endsWith(u8, page, "</html>\n"));
        try expectHas(page, "WPT subtests passing");
    }
    try testing.expectEqual(@as(usize, 9), pages);
}

test "site: every page loads site.js once, deferred, to enhance what its markup already says" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const cases = [_]struct { []const u8, []const u8 }{
        .{ "out/index.html", "<script src=\"site.js\" defer></script>" },
        .{ "out/dom/index.html", "<script src=\"../site.js\" defer></script>" },
        .{ "out/dom/nodes/index.html", "<script src=\"../../site.js\" defer></script>" },
        .{ "out/dom/a.html/index.html", "<script src=\"../../site.js\" defer></script>" },
    };
    for (cases) |c| {
        const page = try readOut(gpa, &f, c[0]);
        defer gpa.free(page);
        try expectHas(page, c[1]);
        try expectBefore(page, c[1], "</head>");
        try testing.expectEqual(@as(usize, 1), std.mem.count(u8, page, "<script"));
    }
}

test "site: the revision history charts WPT subtests, not files" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    // The drawing (the chart script redraws it from the table) is subtests passing
    // and not passing, up to the total.
    try expectHas(index, "band-pass");
    try expectHas(index, "band-fail");
    try testing.expect(std.mem.indexOf(u8, index, "band-clean") == null);
    try testing.expect(std.mem.indexOf(u8, index, "Files by standing") == null);
    // The table leads with subtests, and each row carries what the chart reads.
    try expectHas(index, "<th scope=\"col\">Subtests passing</th><th scope=\"col\">Total subtests</th>");
    try expectHas(index, "<tr data-n=\"2\" data-at=\"2026-09-30T11:21:23\" data-head=\"5c8dd64da\" data-pass=\"5\" data-total=\"8\" data-fail=\"3\" data-timeout=\"0\" data-notrun=\"0\" data-blocking=\"2\" data-files=\"5\">");
    // Before a generation recorded its subtests exactly, the total is the
    // progress report's count of subtests known to exist, marked as such.
    try expectHas(index, "<tr class=\"recon\" data-n=\"1\" data-at=\"2026-09-19T19:55:00\" data-pass=\"3\" data-total=\"6\" data-est=\"1\" data-blocking=\"1\" data-files=\"5\" data-recon=\"1\">");
    try expectHas(index, "<td>3</td><td class=\"est\">6</td><td class=\"est fail\">3</td>");
    try expectHas(index, "<td>5</td><td>8</td><td class=\"fail\">3</td><td class=\"blk\">2</td>");
}

test "site: listing rows carry the keys sorting and filtering read" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const dom = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(dom);
    try expectHas(dom, "<tr data-gate=\"timeout\"><th scope=\"row\"><a href=\"../dom/b.html/\">");
    try expectHas(dom, "<tr data-gate=\"partial\"><th scope=\"row\"><a href=\"../dom/a.html/\">");
    // a.html: 2 of 3 passing, 1 failed.
    try expectHas(dom, "<td class=\"n\" data-v=\"2\" data-of=\"3\"><b>2</b> / 3</td><td class=\"n\" data-v=\"1\"><span class=\"fail\">1</span></td>");
    // dom/nodes/: 0 of 2 passing, one file, one blocking.
    try expectHas(dom, "<td class=\"n\" data-v=\"0\" data-of=\"2\"><b>0</b> / 2</td><td class=\"n\" data-v=\"1\">1</td><td data-v=\"1\">");
}

test "site: paths.json lists every directory and test file, for the search" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const paths = try readOut(gpa, &f, "out/paths.json");
    defer gpa.free(paths);
    try testing.expectEqualStrings(
        \\["dom/","dom/a.html","dom/b.html","dom/nodes/","dom/nodes/c.any.js","url/","url/never.html","url/u.html"]
        \\
    , paths);
}

test "site: unchanged input writes byte-identical files; a new generation rewrites only index.html and the card" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const first = try runFixture(gpa, &f, "one", fixture_worklist);
    try testing.expect(first.written > 0);
    const again = try runFixture(gpa, &f, "one", fixture_worklist);
    try testing.expectEqual(@as(usize, 0), again.written);
    try testing.expectEqual(first.written, again.unchanged);

    // A third generation with the same results: the history moves, nothing else.
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.openDir(testing.io, "one", .{ .iterate = true });
    defer out.close(testing.io);
    const next = try generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = fixture_history_next,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
    }, out);
    try testing.expectEqual(@as(usize, 1), next.written);
    const index = try readOut(gpa, &f, "one/index.html");
    defer gpa.free(index);
    try expectHas(index, "Generation 3, recorded at Crane");
    // Only the index carries a generation or its date.
    var walker = try out.walk(gpa);
    defer walker.deinit();
    while (try walker.next(testing.io)) |e| {
        if (e.kind != .file or !std.mem.endsWith(u8, e.path, ".html") or std.mem.eql(u8, e.path, "index.html")) continue;
        const page = try out.readFileAlloc(testing.io, e.path, gpa, .limited(1 << 24));
        defer gpa.free(page);
        try testing.expect(std.mem.indexOf(u8, page, "Generation") == null);
        try testing.expect(std.mem.indexOf(u8, page, "last updated") == null);
    }
}

test "site: a file that leaves the worklist loses its page; .git is never touched" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/.git", .data = "gitdir: elsewhere\n" });
    try f.tmp.dir.createDirPath(testing.io, "out/data/dirs");
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/data/dirs/dom.json", .data = "{}" });
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/site.js", .data = "old" });
    const smaller =
        \\dom/b.html
        \\url/u.html
        \\
    ;
    const s = try runFixture(gpa, &f, "out", smaller);
    try testing.expect(s.removed >= 5);
    try testing.expect(!exists(&f, "out/dom/a.html/index.html"));
    try testing.expect(!exists(&f, "out/dom/nodes/index.html"));
    try testing.expect(!exists(&f, "out/dom/nodes"));
    // The script-rendered site's leftovers go too.
    try testing.expect(!exists(&f, "out/data/dirs/dom.json"));
    try testing.expect(!exists(&f, "out/site.js"));
    try testing.expect(exists(&f, "out/.git"));
    try testing.expect(exists(&f, "out/.nojekyll"));
    try testing.expect(exists(&f, "out/dom/b.html/index.html"));
}

test "site: index.html carries the social card's tags, and the card is a 1200x630 PNG" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    try expectHas(index, "<meta property=\"og:title\" content=\"Crane WPT results: 5 / 8 WPT subtests passing\">");
    try expectHas(index, "<meta property=\"og:url\" content=\"https://zig-whatwg.github.io/crane/\">");
    try expectHas(index, "<meta property=\"og:image\" content=\"https://zig-whatwg.github.io/crane/card.png?v=");
    try expectHas(index, "<meta name=\"twitter:card\" content=\"summary_large_image\">");
    try expectHas(index, "<meta property=\"og:description\" content=\"3 failed, 0 timed out, 0 not run; 5 test files, 2 blocking.");
    // The tags sit in the head, where crawlers read them.
    try expectBefore(index, "og:image", "</head>");

    const card_bytes = try readOut(gpa, &f, "out/card.png");
    defer gpa.free(card_bytes);
    var img = try png.decode(gpa, card_bytes);
    defer img.deinit(gpa);
    try testing.expectEqual(@as(u32, 1200), img.width);
    try testing.expectEqual(@as(u32, 630), img.height);
}

test "site: index.html opens its body with the direction contract" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    const body = std.mem.indexOf(u8, index, "<body>\n") orelse return error.NoBody;
    const rest = index[body + "<body>\n".len ..];
    try testing.expect(std.mem.startsWith(u8, rest, "<!--\nTHESIS: "));
    try expectHas(rest, "seed a0daf20c");
    try expectHas(rest, "FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md\n-->");
}

test "range: a merge's subject names the branch it merged" {
    try testing.expectEqualStrings("lane/serializable", mergeName("Merge lane/serializable (d6a770df64): [Serializable] platform objects").?);
    try testing.expectEqualStrings("infra/test-aggregation", mergeName("Merge infra/test-aggregation (f476a8c834): one test executable").?);
    try testing.expectEqualStrings("lane/x", mergeName("Merge branch 'lane/x' into main").?);
    try testing.expectEqualStrings("origin/main", mergeName("Merge remote-tracking branch 'origin/main' into crane-upstream").?);
    try testing.expectEqualStrings("fix/retire-oom", mergeName("Merge fix/retire-oom").?);
    try testing.expect(mergeName("chore: codex-indexeddb's Crane tests (gitlink)") == null);
    try testing.expect(mergeName("Merge ") == null);
}

test "range: a first-parent log gives the commits and the merges among them" {
    const a = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(a);
    defer arena_state.deinit();
    const log =
        "2794798eb585e639bd487e4fae1a504c155164c8\t422aac9b30aa\tchore: codex-indexeddb's Crane tests (gitlink)\n" ++
        "422aac9b30aa0000000000000000000000000000\t35a00e7ec4aa 4af556288eaa\tMerge lane/codex-indexeddb (4af556288e, Codex): IndexedDB\n" ++
        "35a00e7ec4aa0000000000000000000000000000\t0c414f3cadaa\tchore: serializable's Crane tests\n" ++
        "0c414f3cadaa0000000000000000000000000000\tab6f5d58d4aa d6a770df64aa\tMerge lane/serializable (d6a770df64): [Serializable]\n" ++
        "e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0\tab6f5d58d4aa 1111111111aa\tMerge\n";
    const r = try parseRange(arena_state.allocator(), "70f48f5704", "2794798eb5", log);
    try testing.expectEqualStrings("70f48f5704", r.since);
    try testing.expectEqualStrings("2794798eb5", r.head);
    try testing.expectEqual(@as(u32, 5), r.commits);
    // Oldest first, as they landed; a merge whose subject names no branch is its commit.
    try testing.expectEqual(@as(usize, 3), r.landed.len);
    try testing.expectEqualStrings("e0e0e0e0e0", r.landed[0]);
    try testing.expectEqualStrings("lane/serializable", r.landed[1]);
    try testing.expectEqualStrings("lane/codex-indexeddb", r.landed[2]);
    // No commits: an empty log.
    const none = try parseRange(arena_state.allocator(), "a", "b", "");
    try testing.expectEqual(@as(u32, 0), none.commits);
    try testing.expectEqual(@as(usize, 0), none.landed.len);
}

const fixture_history_flaky =
    \\{"gate_rule":2,"generations":[
    \\{"n":2,"at":"2026-09-30T11:21:23","head":"5c8dd64da","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3,"sub_passing":5,"sub_targeted":8,"subs":{"passed":5,"failed":3,"timed_out":0,"notrun":0}},
    \\{"n":3,"at":"2026-10-01T09:00:00","head":"6d9ee75eb","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"flaky":1,"retried":6,"retry_skipped":4,"flaky_paths":["dom/b.html"],"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3,"sub_passing":5,"sub_targeted":8,"subs":{"passed":5,"failed":3,"timed_out":0,"notrun":0}}
    \\],"last_statuses":{}}
;

test "site: each generation shows its flaky files beside its blocking files" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, "flaky", .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    _ = try generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = fixture_history_flaky,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
    }, out);
    const index = try readOut(gpa, &f, "flaky/index.html");
    defer gpa.free(index);
    // The table's column, after blocking files.
    try expectHas(index, "<th scope=\"col\">Blocking files</th><th scope=\"col\">Flaky files</th>");
    // A generation that measured it: the count, and an attribute for the chart.
    try expectHas(index, "data-blocking=\"2\" data-files=\"5\" data-flaky=\"1\"");
    try expectHas(index, "<td class=\"blk\">2</td><td class=\"flaky\">1 <small class=\"dim\">of 6 retried, 4 skipped</small></td></tr>");
    try expectHas(index, "data-flaky=\"1\" data-retried=\"6\" data-retry-skipped=\"4\"");
    try expectHas(index, "<dt>Files retried</dt><dd>6</dd>");
    try expectHas(index, "<dt>Retry skipped (unchanged)</dt><dd>4</dd>");
    // One from before the runner retried anything: unknown, not zero.
    try expectHas(index, "<td class=\"blk\">2</td><td class=\"flaky\">&mdash;</td></tr>");
    // The headline: the latest generation's count beside its blocking files.
    try expectHas(index, "<dt>Flaky files</dt><dd>1</dd>");
}

test "range: consecutive generations with known heads are the ranges to ask git for" {
    const a = testing.allocator;
    var arena_state: std.heap.ArenaAllocator = .init(a);
    defer arena_state.deinit();
    const pairs = try rangePairs(arena_state.allocator(), fixture_history_next);
    // Generation 1's head is not recorded, so generation 2 has no range.
    try testing.expectEqual(@as(usize, 1), pairs.len);
    try testing.expectEqualStrings("5c8dd64da", pairs[0].since);
    try testing.expectEqualStrings("6d9ee75eb", pairs[0].head);
}

test "site: a generation names the commits since the previous one, and the merges among them" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, "ranged", .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    const landed = [_][]const u8{ "lane/a", "lane/b" };
    _ = try generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = fixture_history_next,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
        .ranges = &.{.{ .since = "5c8dd64da", .head = "6d9ee75eb", .commits = 3, .landed = &landed }},
    }, out);
    const index = try readOut(gpa, &f, "ranged/index.html");
    defer gpa.free(index);
    // The headline's version: the range, linked to its comparison, and what merged in it.
    try expectHas(index, "Generation 3, recorded at Crane <a href=\"https://github.com/zig-whatwg/crane/compare/5c8dd64da...6d9ee75eb\"><code>5c8dd64da</code>&hellip;<code>6d9ee75eb</code></a>: 3 commits since generation 2, merging <code>lane/a</code> and <code>lane/b</code>");
    // Its row carries the range for the chart, and says it in words.
    try expectHas(index, "data-head=\"6d9ee75eb\" data-since=\"5c8dd64da\" data-commits=\"3\" data-landed=\"lane/a lane/b\"");
    try expectHas(index, "<td><a href=\"https://github.com/zig-whatwg/crane/compare/5c8dd64da...6d9ee75eb\"><code>5c8dd64da</code>&hellip;<code>6d9ee75eb</code></a><span class=\"landed\">merged <code>lane/a</code>, <code>lane/b</code></span></td>");
    // A generation with no range keeps its single commit.
    try expectHas(index, "<td><code>5c8dd64da</code></td>");
}

fn runFixtureExempt(gpa: Allocator, f: *Fixture, out_name: []const u8, exemptions: []const u8, diag: *model.ExemptionDiag) !Summary {
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, out_name, .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    return generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = fixture_history,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
        .exemptions_text = exemptions,
        .exemption_diag = diag,
    }, out);
}

fn fixtureExemption(comptime path: []const u8) []const u8 {
    return "[" ++ path ++ "]\n" ++
        \\why = all three browsers keep the old behaviour on purpose
        \\spec = https://example.org/spec#step
        \\chrome.result = wpt.fyi run 6218298311311360: 0/2
        \\chrome.intent = https://issues.chromium.org/issues/11
        \\firefox.result = wpt.fyi run 4877098740350976: 0/2
        \\firefox.intent = https://bugzilla.mozilla.org/show_bug.cgi?id=22
        \\safari.result = wpt.fyi run 5164107446878208: 0/2
        \\safari.intent = https://github.com/WebKit/standards-positions/issues/33
        \\
    ;
}

test "site: an exempt file that would block is its own group, with its evidence, never blocking" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    // c.any.js is NONE-PASSED (blocks); url/u.html is clean (does not).
    const text = comptime fixtureExemption("dom/nodes/c.any.js") ++ fixtureExemption("url/u.html");
    _ = try runFixtureExempt(gpa, &f, "out", text, &diag);

    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    // Blocking drops from 2 (b.html TIMEOUT, c.any.js NONE-PASSED) to 1.
    try expectHas(index, "<div class=\"blk\"><dt>Blocking files</dt><dd>1</dd>");
    try expectHas(index, "<dt><span class=\"key key-exempt\"></span>Exempt</dt><dd>1</dd>");
    // The group, after the status and before the contents, with every browser's evidence.
    try expectBefore(index, "id=\"status\"", "id=\"exempt\"");
    try expectBefore(index, "id=\"exempt\"", "id=\"contents\"");
    try expectHas(index, "<a href=\"dom/nodes/c.any.js/\"><code>dom/nodes/c.any.js</code></a> <span class=\"gate gate-exempt\">Exempt</span>");
    try expectHas(index, "all three browsers keep the old behaviour on purpose");
    try expectHas(index, "<dt>Chrome</dt><dd>wpt.fyi run 6218298311311360: 0/2; intent: <a href=\"https://issues.chromium.org/issues/11\">");
    try expectHas(index, "<dt>Firefox</dt><dd>wpt.fyi run 4877098740350976: 0/2; intent: <a href=\"https://bugzilla.mozilla.org/show_bug.cgi?id=22\">");
    try expectHas(index, "<dt>Safari</dt><dd>wpt.fyi run 5164107446878208: 0/2; intent: <a href=\"https://github.com/WebKit/standards-positions/issues/33\">");
    // A listed file that does not block keeps its standing.
    try expectHas(index, "<a href=\"url/u.html/\"><code>url/u.html</code></a> <span class=\"gate gate-clean\">Clean</span>");
    try expectHas(index, "Not counted among them: 1 file that would block is <a href=\"#exempt\">exempt</a>");

    // The file's own page says so, with the evidence.
    const page = try readOut(gpa, &f, "out/dom/nodes/c.any.js/index.html");
    defer gpa.free(page);
    try expectHas(page, "<span class=\"gate gate-exempt\">Exempt</span>");
    try expectHas(page, "Exempt from the 0.1 gate");
    try expectHas(page, "https://github.com/WebKit/standards-positions/issues/33");
    // Its directory counts it as exempt, not blocking.
    const dir = try readOut(gpa, &f, "out/dom/nodes/index.html");
    defer gpa.free(dir);
    try testing.expect(std.mem.indexOf(u8, dir, "Blocking files</dt><dd>1") == null);
    try expectHas(dir, "<tr data-gate=\"exempt\"");
}

test "site: no exemptions write the same bytes as before; an invalid one stops the site" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    _ = try runFixture(gpa, &f, "plain", fixture_worklist);
    _ = try runFixtureExempt(gpa, &f, "empty", "# no entries\n", &diag);
    const a = try readOut(gpa, &f, "plain/index.html");
    defer gpa.free(a);
    const b = try readOut(gpa, &f, "empty/index.html");
    defer gpa.free(b);
    try testing.expectEqualStrings(a, b);
    try testing.expect(std.mem.indexOf(u8, a, "exempt") == null);

    // Missing a browser's evidence.
    const no_safari = comptime blk: {
        const full = fixtureExemption("dom/b.html");
        const cut = std.mem.indexOf(u8, full, "safari.intent").?;
        break :blk full[0..cut];
    };
    try testing.expectError(error.InvalidExemption, runFixtureExempt(gpa, &f, "bad1", no_safari, &diag));
    try testing.expect(std.mem.indexOf(u8, diag.message, "safari.intent") != null);
    // A path the worklist does not have.
    diag = .{};
    try testing.expectError(error.InvalidExemption, runFixtureExempt(gpa, &f, "bad2", fixtureExemption("dom/typo.html"), &diag));
    try testing.expectEqualStrings("dom/typo.html", diag.path);
}

// ============================================================================
// Tests: a reference run beside Crane's (lane chromeref1)
// ============================================================================

/// Chrome's results on the fixture's worklist, as reference.write makes them:
/// dom/a.html 3 of 3 (Crane 2 of 3), dom/b.html 1 of 1 (Crane TIMEOUT),
/// dom/nodes/c.any.js 2 of 2 with one test URL missing (Crane NONE-PASSED),
/// url/u.html 1 of 3 (Crane 3 of 3), url/never.html TIMEOUT 1 of 2 (Crane has
/// not run it).
const fixture_reference =
    \\{"format":"crane-wpt-reference/1","engine":"chrome",
    \\"run":{"browser_version":"150.0.7000.1","webdriver_version":"150.0.7000.2","channel":"stable","wpt_revision":"56d7fe562b35dfcb063fac457f24bd0a38205481","worklist_commit":"0c228a97aa9","processes":5,"host":"chat.local","command":"wpt run chrome","date":"2026-11-04T11:00:00Z"},
    \\"product":"chrome","time_start":1793790000000,"time_end":1793793600000,
    \\"timing":{"processes":5,"reference":{"wall_s":3600.5,"user_s":9000,"sys_s":1200},"crane":{"wall_s":2400,"user_s":8000,"sys_s":400,"files":5,"runner":"main-0c228a97aa"},"overhead":{"files":200,"reference":{"wall_s":60,"user_s":100,"sys_s":20},"crane":{"wall_s":10,"user_s":30,"sys_s":5}}},
    \\"coverage":{"sources":5,"sources_in_manifest":5,"sources_reported":5,"urls_expected":7,"urls_reported":6,"urls_skipped":0,"urls_missing":1,"urls_outside":0,"urls_unknown":0},
    \\"files":{
    \\"dom/a.html":{"engine":"chrome","status":"OK","passed":3,"failed":0,"timed_out":0,"notrun":0,"urls":1,"missing_urls":0,"message":null},
    \\"dom/b.html":{"engine":"chrome","status":"OK","passed":1,"failed":0,"timed_out":0,"notrun":0,"urls":1,"missing_urls":0,"message":null},
    \\"dom/nodes/c.any.js":{"engine":"chrome","status":"OK","passed":2,"failed":0,"timed_out":0,"notrun":0,"urls":1,"missing_urls":1,"message":null},
    \\"url/never.html":{"engine":"chrome","status":"TIMEOUT","passed":1,"failed":0,"timed_out":1,"notrun":0,"urls":1,"missing_urls":0,"message":"slow"},
    \\"url/u.html":{"engine":"chrome","status":"OK","passed":1,"failed":2,"timed_out":0,"notrun":0,"urls":1,"missing_urls":0,"message":null}
    \\}}
;

fn runFixtureRef(gpa: Allocator, f: *Fixture, out_name: []const u8, ref_json: ?[]const u8) !Summary {
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, out_name, .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    return generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = fixture_history,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
        .reference_json = ref_json,
    }, out);
}

test "site: a reference run is shown beside Crane's on the same files, never in Crane's numbers" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const s = try runFixtureRef(gpa, &f, "out", fixture_reference);
    try testing.expectEqual(@as(usize, 5), s.reference_files);

    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    // Crane's headline is Crane's alone.
    try expectHas(index, "<span class=\"hl-pass\">5</span><span class=\"hl-of\"> / 8</span>");
    try expectHas(index, "<div class=\"blk\"><dt>Blocking files</dt><dd>2</dd>");
    // The comparison: its own section after the scope, before the contents.
    try expectBefore(index, "id=\"status\"", "id=\"versus\"");
    try expectBefore(index, "id=\"versus\"", "id=\"contents\"");
    try expectHas(index, "<h2 id=\"versus-h\">Crane and Chrome</h2>");
    try expectHas(index, "Chrome <code>150.0.7000.1</code>");
    try expectHas(index, "ChromeDriver <code>150.0.7000.2</code>");
    try expectHas(index, "<code>56d7fe562b</code>");
    try expectHas(index, "4 Nov 2026");
    // Side by side: subtests passing of reported, and blocking files, for both.
    try expectHas(index, "<tr><th scope=\"row\">WPT subtests passing</th><td class=\"n\" data-v=\"5\" data-of=\"8\"><b>5</b> / 8</td><td class=\"n\" data-v=\"8\" data-of=\"11\"><b>8</b> / 11</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Blocking files</th><td class=\"n blk\">2</td><td class=\"n blk\">1</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Files with a result</th><td class=\"n\">4</td><td class=\"n\">5</td></tr>");
    // Where they differ, both directions, on the comparison page.
    try expectHas(index, "<a href=\"chrome.html#ahead-ref\">3 files</a> where Chrome passes subtests Crane does not (4 subtests)");
    try expectHas(index, "<a href=\"chrome.html#ahead-crane\">1 file</a> where Crane passes subtests Chrome does not (2 subtests)");
    // The suite tables carry Chrome's count beside Crane's.
    try expectHas(index, "<th scope=\"col\" class=\"n\">Chrome</th>");

    // A directory page: Chrome's numbers for the directory, and per file.
    const dom = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(dom);
    try expectHas(dom, "<p class=\"figures-ref\"><span class=\"ref-name\">Chrome</span> <b>6</b> / 6 WPT subtests passing on the same files, <span class=\"quiet\">none blocking</span></p>");
    try expectHas(dom, "<td class=\"n\" data-v=\"2\" data-of=\"3\"><b>2</b> / 3</td><td class=\"n\" data-v=\"3\" data-of=\"3\"><b>3</b> / 3</td>");

    // A file page: Chrome's standing and count beside Crane's.
    const b = try readOut(gpa, &f, "out/dom/b.html/index.html");
    defer gpa.free(b);
    try expectHas(b, "<div><dt>Chrome</dt><dd><span class=\"gate gate-clean\">Clean</span> <b>1</b> / 1 WPT subtests passing <span class=\"quiet\">runner status <code>OK</code></span></dd></div>");
    const c = try readOut(gpa, &f, "out/dom/nodes/c.any.js/index.html");
    defer gpa.free(c);
    try expectHas(c, "1 of its test URLs has no Chrome result");
    const never = try readOut(gpa, &f, "out/url/never.html/index.html");
    defer gpa.free(never);
    try expectHas(never, "<span class=\"gate gate-unrun\">Not run</span>");
    try expectHas(never, "<div><dt>Chrome</dt><dd><span class=\"gate gate-timeout g-block\">TIMEOUT</span> <b>1</b> / 2 WPT subtests passing");

    // The comparison page: Chrome ahead by most subtests first, then Crane ahead,
    // then the files only one of them ran.
    const cmp = try readOut(gpa, &f, "out/chrome.html");
    defer gpa.free(cmp);
    try expectBefore(cmp, "id=\"ahead-ref\"", "id=\"ahead-crane\"");
    try expectBefore(cmp, "id=\"ahead-crane\"", "id=\"only-one\"");
    try expectBefore(cmp, "<a href=\"dom/nodes/c.any.js/\">", "<a href=\"dom/a.html/\">");
    try expectBefore(cmp, "<a href=\"dom/a.html/\">", "<a href=\"dom/b.html/\">");
    try expectBefore(cmp, "<a href=\"dom/b.html/\">", "id=\"ahead-crane\"");
    try expectBefore(cmp, "id=\"ahead-crane\"", "<a href=\"url/u.html/\">");
    try expectBefore(cmp, "id=\"only-one\"", "<a href=\"url/never.html/\">");
    try expectHas(cmp, "<td class=\"n\" data-v=\"2\">+2</td>");
    try expectHas(cmp, "<table class=\"listing listing-compare\">");
    if (pages_mod.needsScript(cmp)) |why| {
        std.debug.print("\nchrome.html needs script: {s}\n", .{why});
        return error.TestPageNeedsScript;
    }
    // Every page's contents rail leads to it; the rail names no version and no number.
    try expectHas(dom, "<li class=\"toc-front\"><a href=\"../chrome.html\"><span class=\"secno\"></span><span class=\"toc-name\">Crane and Chrome</span></a></li>");
    try expectHas(index, "<li class=\"toc-front\"><a href=\"chrome.html\"><span class=\"secno\"></span><span class=\"toc-name\">Crane and Chrome</span></a></li>");
}

test "site: wall time is shown for both engines with the harness overhead split out" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixtureRef(gpa, &f, "out", fixture_reference);
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    try expectHas(index, "<tr><th scope=\"row\">The worklist, wall clock</th><td class=\"n\">40 min 0 s</td><td class=\"n\">1 h 0 min</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">CPU, user + system</th><td class=\"n\">2 h 20 min</td><td class=\"n\">2 h 50 min</td></tr>");
    // 200 trivial files in 10 s and 60 s with 5 runners: 250 ms and 1.50 s each.
    try expectHas(index, "<tr><th scope=\"row\">One empty test, harness alone</th><td class=\"n\">250 ms</td><td class=\"n\">1.50 s</td></tr>");
    try expectHas(index, "5 runners each");
}

test "site: a reference run's records are never Crane's" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream ++
        \\{"engine":"chrome","test":"/dom/b.html","status":"OK","message":null,"subtests":[{"name":"chrome's","status":"PASS","message":null}]}
        \\
    );
    defer f.deinit();
    // A run directory named reference/ is not a run: a record that names a
    // journal there is not located in it.
    try f.tmp.dir.createDirPath(testing.io, "results/reference/chrome-150");
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "results/reference/stray.jsonl", .data = "{}\n" });
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "results/reference/chrome-150/reference.json", .data = fixture_reference });
    const stray = try f.results.statFile(testing.io, "reference/stray.jsonl", .{});
    const stray_mtime = @as(f64, @floatFromInt(stray.mtime.nanoseconds)) / 1e9;

    // The fixture's state, with url/u.html's record from a journal under
    // reference/, and one of Chrome's records for url/never.html, which Crane
    // has not run.
    const st = try std.fmt.allocPrint(gpa,
        \\{{"dom/a.html":{{"path":"dom/a.html","status":"OK","passed":2,"failed":1,"timed_out":0,"notrun":0,"_journal":"journal.jsonl","_mtime":{d}}},
        \\"dom/nodes/c.any.js":{{"path":"dom/nodes/c.any.js","status":"OK","passed":0,"failed":2,"timed_out":0,"notrun":0,"_journal":"journal.jsonl","_mtime":{d}}},
        \\"dom/b.html":{{"path":"dom/b.html","status":"TIMEOUT","passed":0,"failed":0,"timed_out":0,"notrun":0,"message":"took too long","_journal":"journal.jsonl","_mtime":{d}}},
        \\"url/u.html":{{"path":"url/u.html","status":"OK","passed":3,"failed":0,"timed_out":0,"notrun":0,"_journal":"stray.jsonl","_mtime":{d}}},
        \\"url/never.html":{{"engine":"chrome","path":"url/never.html","status":"OK","passed":9,"failed":0,"timed_out":0,"notrun":0,"_journal":"journal.jsonl","_mtime":{d}}}}}
    , .{ f.journal_mtime, f.journal_mtime, f.journal_mtime, stray_mtime, f.journal_mtime });
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, "out", .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    const s = try generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = fixture_history,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
    }, out);
    try testing.expectEqual(@as(usize, 1), s.refused_records);
    try testing.expectEqual(@as(usize, 1), s.refused_stream_lines);

    // Chrome's 9 passes are nowhere in Crane's numbers: the file is not run.
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    try expectHas(index, "<span class=\"hl-pass\">5</span><span class=\"hl-of\"> / 8</span>");
    const never = try readOut(gpa, &f, "out/url/never.html/index.html");
    defer gpa.free(never);
    try expectHas(never, "<span class=\"gate gate-unrun\">Not run</span>");
    // Chrome's stream line beside Crane's journal is not Crane's detail.
    const b = try readOut(gpa, &f, "out/dom/b.html/index.html");
    defer gpa.free(b);
    try testing.expect(std.mem.indexOf(u8, b, "chrome&rsquo;s") == null);
    try testing.expect(std.mem.indexOf(u8, b, "chrome's") == null);
    try expectHas(b, "No per-subtest data for this file.");
    // reference/ is never named as a run.
    const u = try readOut(gpa, &f, "out/url/u.html/index.html");
    defer gpa.free(u);
    try testing.expect(std.mem.indexOf(u8, u, "reference/stray") == null);
    // Without a reference given, there is no comparison.
    try testing.expect(!exists(&f, "out/chrome.html"));
    try testing.expect(std.mem.indexOf(u8, index, "id=\"versus\"") == null);
}

test "site: no reference writes the same bytes as before; an invalid one stops the site" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "plain", fixture_worklist);
    _ = try runFixtureRef(gpa, &f, "none", null);
    const a = try readOut(gpa, &f, "plain/dom/index.html");
    defer gpa.free(a);
    const b = try readOut(gpa, &f, "none/dom/index.html");
    defer gpa.free(b);
    try testing.expectEqualStrings(a, b);
    try testing.expect(std.mem.indexOf(u8, a, "Chrome") == null);

    const crane_ref = try std.mem.replaceOwned(u8, gpa, fixture_reference, "\"engine\":\"chrome\",\n\"run\"", "\"engine\":\"crane\",\n\"run\"");
    defer gpa.free(crane_ref);
    try testing.expectError(error.InvalidReference, runFixtureRef(gpa, &f, "bad", crane_ref));
}
