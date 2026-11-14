//! Crane's public WPT results site: the generator.
//!
//!     zig build wpt-site [-- --out=<dir> --no-commit ...]
//!
//! Reads the progress report's accumulated state and history, the worklist,
//! and any per-subtest wptreport streams, and writes the site to --out as
//! finished HTML: index.html, one page per directory of the WPT tree holding a
//! section for each test file in it (no test file has a page of its own since
//! 2026-11-07), 404.html, the stylesheet and faces from tools/wpt_site/assets/,
//! the social card (card.png), and paths.json for the search. No page needs
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
    /// tools/wpt_generation_hosts.txt (model.parseSweepHosts): where each run
    /// ran; "" names no host.
    hosts_text: []const u8 = "",
    /// Set when the hosts file is invalid (generate then fails with
    /// error.InvalidHosts): where, and why.
    hosts_diag: ?*model.ExemptionDiag = null,
    /// A reference run's reference.json: another engine's results on the same
    /// worklist (reference.zig), shown beside Crane's and never counted as
    /// Crane's. Null: no comparison.
    reference_json: ?[]const u8 = null,
    /// Set when the reference is invalid (generate then fails with
    /// error.InvalidReference): why.
    reference_diag: ?*reference.Diag = null,
    /// How much HTML one page may carry (pages.Budget).
    budget: pages_mod.Budget = .{},
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
/// git's own "Merge branch 'x'" / "Merge remote-tracking branch 'x'"; the
/// integrator's "Merge lane x batch 5 (sha; ...): ..." and "Merge lane x
/// (sha): ..." name the lane's branch, `lane/x`; "Merge main <sha> ..." is
/// `main`. Never a name with a space in it: the history row's data-landed
/// is a space-separated list.
pub fn mergeName(arena: Allocator, subject: []const u8) Allocator.Error!?[]const u8 {
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
    // "lane <name> ...": the lane's branch is lane/<name> (the integrator's
    // subjects since lane batches began, e.g. "Merge lane perf3 batch 5 (...)").
    const lane = "lane ";
    if (std.mem.startsWith(u8, rest, lane)) {
        const name = rest[lane.len..];
        const end = std.mem.indexOfAny(u8, name, " (:,;") orelse name.len;
        if (end > 0) return try std.fmt.allocPrint(arena, "lane/{s}", .{name[0..end]});
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
        try landed.append(arena, (try mergeName(arena, subject)) orelse hash[0..@min(hash.len, 10)]);
    }
    std.mem.reverse([]const u8, landed.items);
    return .{ .since = since, .head = head, .commits = commits, .landed = landed.items };
}

pub const Summary = struct {
    files: usize = 0,
    detail_files: usize = 0,
    dir_pages: usize = 0,
    /// Test files, each a section of its directory's page (or of a part page).
    file_sections: usize = 0,
    /// Directory pages over the budget with their passing subtests named,
    /// which count them instead; and those still over it, split into parts.
    counted_pages: usize = 0,
    split_dirs: usize = 0,
    part_pages: usize = 0,
    written: usize = 0,
    unchanged: usize = 0,
    removed: usize = 0,
    /// Every file the site holds, and their bytes.
    outputs: usize = 0,
    bytes: u64 = 0,
    /// The largest files the site holds, largest first.
    largest: [10]Largest = @splat(.{}),
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
        return s.largest[0].path();
    }

    fn noteSize(s: *Summary, rel: []const u8, bytes: u64) void {
        var i: usize = s.largest.len;
        while (i > 0 and bytes > s.largest[i - 1].bytes) i -= 1;
        if (i == s.largest.len) return;
        var j: usize = s.largest.len - 1;
        while (j > i) : (j -= 1) s.largest[j] = s.largest[j - 1];
        s.largest[i] = .{ .bytes = bytes };
        s.largest[i].len = @min(rel.len, s.largest[i].buf.len);
        @memcpy(s.largest[i].buf[0..s.largest[i].len], rel[0..s.largest[i].len]);
    }
};

pub const Largest = struct {
    bytes: u64 = 0,
    buf: [256]u8 = undefined,
    len: usize = 0,

    pub fn path(l: *const Largest) []const u8 {
        return l.buf[0..l.len];
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
        o.summary.noteSize(rel, bytes.len);
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
    /// is never touched, nor `performance/` (tools/perf_bench writes it) or
    /// `frameworks/` (tools/fw_matrix's report).
    fn prune(o: *Output) !void {
        var stale: std.ArrayList([]const u8) = .empty;
        var dirs: std.ArrayList([]const u8) = .empty;
        var walker = try o.dir.walkSelectively(o.gpa);
        defer walker.deinit();
        while (try walker.next(o.io)) |e| {
            if (e.depth() == 1 and std.mem.eql(u8, e.basename, ".git")) continue;
            if (e.depth() == 1 and (std.mem.eql(u8, e.basename, performance_dir) or std.mem.eql(u8, e.basename, frameworks_dir))) continue;
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

/// A directory's test file sections (pages.writeFileSection), rendered from
/// their result streams. The bytes live until the next `render`.
const Sections = struct {
    gpa: Allocator,
    site: *const pages_mod.Site,
    streams: *const std.StringArrayHashMapUnmanaged(std.ArrayList(Line)),
    out: std.heap.ArenaAllocator,
    detail: std.heap.ArenaAllocator,

    fn deinit(s: *Sections) void {
        s.out.deinit();
        s.detail.deinit();
    }

    /// `files` (indices into `Site.files`), each one's section; `names`:
    /// passing subtests named (`pages.SectionOptions`).
    fn render(s: *Sections, files: []const usize, names: bool) ![]const []const u8 {
        _ = s.out.reset(.retain_capacity);
        const a = s.out.allocator();
        const list = try a.alloc([]const u8, files.len);
        for (files, list) |fi, *dst| {
            _ = s.detail.reset(.retain_capacity);
            const f = &s.site.files[fi];
            const detail: []const pages_mod.SubtestRun = if (s.streams.getPtr(f.path)) |lines|
                try parseDetail(s.detail.allocator(), lines.items)
            else
                &.{};
            var w: Io.Writer.Allocating = .init(a);
            try pages_mod.writeFileSection(&w.writer, s.gpa, s.site, f, detail, .{ .passing_names = names });
            dst.* = w.written();
        }
        return list;
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
    /// Both engines' totals over the files both have a result for, and how many.
    crane: model.Totals = .{},
    ref: model.Totals = .{},
    both: usize = 0,
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
    var crane: model.Totals = .{};
    var ref: model.Totals = .{};
    var both: usize = 0;
    for (files, 0..) |f, i| {
        const rv = f.ref orelse {
            if (f.status != null) try only_crane.append(arena, i);
            continue;
        };
        if (f.status == null) {
            try only_ref.append(arena, i);
            continue;
        }
        crane.add(f.gate, f.counts);
        ref.add(rv.gate, rv.counts);
        both += 1;
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
    return .{ .crane = crane, .ref = ref, .both = both, .ahead_ref = ahead_ref.items, .ahead_crane = ahead_crane.items, .only_ref = only_ref.items, .only_crane = only_crane.items };
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
    // Where each generation was swept: its largest run's line in
    // tools/wpt_generation_hosts.txt. Invalid lines stop the site.
    var local_hdiag: model.ExemptionDiag = .{};
    const hosts = try model.parseSweepHosts(arena, in.hosts_text, in.hosts_diag orelse &local_hdiag);
    for (generations) |*g| {
        const src = g.mainSource() orelse continue;
        for (hosts) |*h| if (std.mem.eql(u8, h.label, src.label)) {
            g.swept = h;
            break;
        };
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
        .main_run = pages_mod.mainRun(&runs),
        .history = generations,
        .wpt = in.wpt,
        .worklist_name = in.worklist_name,
        .detail_files = summary.detail_files,
        .site_url = in.site_url,
        .card_ref = card_ref,
        .exemptions = exemptions,
        .hosts_listed = hosts.len > 0,
        .reference = ref_ptr,
        .both_crane = cmp.crane,
        .both_ref = cmp.ref,
        .both = cmp.both,
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

    aw.clearRetainingCapacity();
    try pages_mod.write404(&aw.writer, &site);
    try o.put("404.html", aw.written());

    // Each directory's page, with a section for each test file in it, held
    // to the budget (pages.Budget): every passing subtest named; over it,
    // counted instead; still over it, the sections on part pages.
    var sections: Sections = .{ .gpa = gpa, .site = &site, .streams = &streams, .out = .init(gpa), .detail = .init(gpa) };
    defer sections.deinit();
    const budget = in.budget.bytes;
    for (dir_keys) |k| {
        if (k.len == 0) continue;
        const d = dirs.getPtr(k).?;
        var body: pages_mod.DirBody = .{ .sections = try sections.render(d.files, true), .budget_bytes = budget };
        aw.clearRetainingCapacity();
        try pages_mod.writeDirPage(&aw.writer, &site, d, body);
        if (aw.written().len > budget and d.files.len > 0) {
            body = .{ .sections = try sections.render(d.files, false), .counted = true, .budget_bytes = budget };
            aw.clearRetainingCapacity();
            try pages_mod.writeDirPage(&aw.writer, &site, d, body);
            if (aw.written().len <= budget) {
                summary.counted_pages += 1;
            } else {
                // Parts: the sections in order, a new part when the next would
                // carry this one past what the page leaves for them.
                var in_sections: usize = 0;
                for (body.sections) |sec| in_sections += sec.len;
                const room = budget -| (aw.written().len - in_sections);
                const parts = try arena.alloc(usize, d.files.len);
                var part: usize = 1;
                var in_part: usize = 0;
                for (body.sections, 0..) |sec, j| {
                    if (in_part > 0 and in_part + sec.len > room) {
                        part += 1;
                        in_part = 0;
                    }
                    parts[j] = part;
                    in_part += sec.len;
                }
                const split: pages_mod.DirBody = .{ .counted = true, .parts = parts, .part_count = part, .budget_bytes = budget };
                var first: usize = 0;
                while (first < d.files.len) {
                    var end = first;
                    while (end < d.files.len and parts[end] == parts[first]) end += 1;
                    aw.clearRetainingCapacity();
                    try pages_mod.writePartPage(&aw.writer, &site, d, parts[first], part, d.files[first..end], body.sections[first..end], split);
                    var pbuf: [24]u8 = undefined;
                    try o.put(try std.fmt.allocPrint(arena, "{s}{s}index.html", .{ k, pages_mod.partDir(&pbuf, parts[first]) }), aw.written());
                    summary.part_pages += 1;
                    first = end;
                }
                summary.split_dirs += 1;
                aw.clearRetainingCapacity();
                try pages_mod.writeDirPage(&aw.writer, &site, d, split);
            }
        }
        try o.put(try std.fmt.allocPrint(arena, "{s}index.html", .{k}), aw.written());
        summary.dir_pages += 1;
        summary.file_sections += d.files.len;
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
        \\                [--exemptions=<txt>] [--hosts=<txt>] [--reference=<reference.json>|--no-reference] [--no-commit]
        \\       wpt_site import-reference --engine=<chrome|firefox|safari> --report=<wptreport.json>
        \\                --manifest=<MANIFEST.json> --worklist=<txt> --meta=<run.json> --out=<dir>
        \\
        \\Defaults are the repository's: tmp/wpt-progress-state.json, wpt-results/progress-history.json,
        \\tests/wpt_0_1_worklist.txt, wpt-results/, tools/wpt_site/assets/, wpt-results/site/, tests/wpt/,
        \\https://zig-whatwg.github.io/crane/ (the absolute URL the social tags name),
        \\tools/wpt_gate_exemptions.txt, tools/wpt_generation_hosts.txt, and the newest Chrome run under
        \\wpt-results/reference/.
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
/// /performance/, beside this site in the same gh-pages tree: tools/perf_bench
/// writes it (docs/performance.md), so this generator neither prunes it nor
/// commits it.
pub const performance_dir = "performance";
/// /frameworks/, likewise: tools/fw_matrix's report, the JS framework
/// compatibility matrix, published into the same tree.
pub const frameworks_dir = "frameworks";

/// What a generation's commit stages: everything this generator wrote -
/// --force, because no ignore rule may decide what ships - but performance/
/// and frameworks/, which their own tools' publications commit.
pub const stage_argv = [_][]const u8{ "git", "add", "-A", "--force", "--", ".", ":(exclude)" ++ frameworks_dir, ":(exclude)" ++ performance_dir };

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
    _ = capture(arena, io, out, &stage_argv) orelse return error.GitFailed;
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
    var hosts_path: []const u8 = "tools/wpt_generation_hosts.txt";
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
        if (std.mem.eql(u8, key, "--no-commit")) commit = false else if (eq == null) usage() else if (std.mem.eql(u8, key, "--state")) state_path = val else if (std.mem.eql(u8, key, "--history")) history_path = val else if (std.mem.eql(u8, key, "--worklist")) worklist_path = val else if (std.mem.eql(u8, key, "--results")) results_path = val else if (std.mem.eql(u8, key, "--assets")) assets_path = val else if (std.mem.eql(u8, key, "--out")) out_path = val else if (std.mem.eql(u8, key, "--wpt-root")) wpt_root = val else if (std.mem.eql(u8, key, "--site-url")) site_url = val else if (std.mem.eql(u8, key, "--exemptions")) exemptions_path = val else if (std.mem.eql(u8, key, "--hosts")) hosts_path = val else usage();
    }

    const cwd = Dir.cwd();
    const state = try cwd.readFileAlloc(io, state_path, arena, .limited(1 << 31));
    const history = try cwd.readFileAlloc(io, history_path, arena, .limited(1 << 31));
    const worklist = try cwd.readFileAlloc(io, worklist_path, arena, .limited(1 << 28));
    const exemptions = try cwd.readFileAlloc(io, exemptions_path, arena, .limited(1 << 24));
    const hosts = try cwd.readFileAlloc(io, hosts_path, arena, .limited(1 << 24));
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
    var hdiag: model.ExemptionDiag = .{};
    var rdiag: reference.Diag = .{};
    const summary = generate(init.gpa, io, .{
        .hosts_text = hosts,
        .hosts_diag = &hdiag,
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
        error.InvalidHosts => {
            std.debug.print("wpt-site: {s}:{d}: {s}\n", .{ hosts_path, hdiag.line, hdiag.message });
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
        "wpt-site: generation {d} (Crane {s}): {d} test files, {d} with subtest detail; {d} directory pages holding {d} test file sections " ++
            "({d} counting their passing subtests and {d} split into {d} part pages, to stay within {d} bytes); " ++
            "{d} files in the site, {d} bytes; {d} written, {d} unchanged, {d} removed, in {s}\n",
        .{
            summary.generation,    summary.head(),        summary.files,      summary.detail_files, summary.dir_pages,
            summary.file_sections, summary.counted_pages, summary.split_dirs, summary.part_pages,   pages_mod.Budget.default_bytes,
            summary.outputs,       summary.bytes,         summary.written,    summary.unchanged,    summary.removed,
            out_path,
        },
    );
    std.debug.print("wpt-site: the largest files:\n", .{});
    for (&summary.largest) |*l| if (l.bytes > 0) std.debug.print("  {d:>10}  {s}\n", .{ l.bytes, l.path() });
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
    try expectHas(index, "<a href=\"dom/#a.html\">");
    // The revision history: a drawn chart and a table, no script.
    try expectHas(index, "<svg class=\"chart-svg chart-wide\"");
    try expectHas(index, "<td><code>5c8dd64da</code></td>");
    // The phrase the user ruled out, and a pass percentage, are nowhere.
    try testing.expect(std.mem.indexOf(u8, index, "passing every subtest") == null);
    try testing.expect(std.mem.indexOf(u8, index, "% of subtests") == null);
}

test "site: one page per directory, mirroring the WPT tree; each test file a section of its directory's page" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    // dom/, dom/nodes/, url/; five test files, each a section, none a page.
    try testing.expectEqual(@as(usize, 3), s.dir_pages);
    try testing.expectEqual(@as(usize, 5), s.file_sections);
    try testing.expectEqual(@as(usize, 0), s.part_pages);
    for ([_][]const u8{ "out/dom/index.html", "out/dom/nodes/index.html", "out/url/index.html", "out/card.png", "out/404.html" }) |p| if (!exists(&f, p)) {
        std.debug.print("\nmissing page {s}\n", .{p});
        return error.TestExpectedPage;
    };
    for ([_][]const u8{ "out/dom/a.html", "out/dom/b.html", "out/dom/nodes/c.any.js", "out/url/u.html", "out/url/never.html" }) |p| {
        try testing.expect(!exists(&f, p));
    }

    const dom = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(dom);
    try expectHas(dom, "<h1 class=\"page-title\"><span class=\"secno\">1</span><code>dom/</code></h1>");
    try expectHas(dom, "<span class=\"fg-pass\">2</span><span class=\"fg-of\"> / 5</span>");
    try expectHas(dom, "<a href=\"../dom/nodes/\"><span class=\"dir-no\">1.1</span>");
    try expectHas(dom, "<link rel=\"stylesheet\" href=\"../site.css\">");
    // The rail marks the suite this page belongs to.
    try expectHas(dom, "<a href=\"../dom/\" aria-current=\"page\">");
    // Each file directly in dom/ is a section of this page, its name its id,
    // in name order; its summary is its row: name, subtests passing, failed, standing.
    try expectHas(dom, "<details class=\"tf\" id=\"a.html\" data-gate=\"partial\" data-pass=\"2\" data-of=\"3\" data-failed=\"1\"><summary><span class=\"tf-name\"><code>a.<wbr>html</code></span><span class=\"tf-n\"><b>2</b> / 3<span class=\"tf-lbl\"> passing</span></span><span class=\"tf-fail\"><span class=\"fail\">1</span><span class=\"tf-lbl\"> failed</span></span><span class=\"tf-gate\"><span class=\"gate gate-partial\">With failures</span></span></summary>");
    try expectHas(dom, "<details class=\"tf\" id=\"b.html\" data-gate=\"timeout\"");
    try expectHas(dom, "<span class=\"gate gate-timeout g-block\">TIMEOUT</span>");
    try expectBefore(dom, "id=\"a.html\"", "id=\"b.html\"");
    // The column heads, once.
    try expectHas(dom, "<div class=\"tf-head\"><span>Test file</span><span>Subtests passing</span><span>Failed</span><span>Standing</span></div>");
    // A file in dom/nodes/ is on dom/nodes/'s page, not dom/'s.
    try testing.expect(std.mem.indexOf(u8, dom, "id=\"c.any.js\"") == null);

    const nodes = try readOut(gpa, &f, "out/dom/nodes/index.html");
    defer gpa.free(nodes);
    try expectHas(nodes, "<li><a href=\"../../dom/\"><code>dom/</code></a></li><li aria-current=\"page\"><code>nodes/</code></li>");
    try expectHas(nodes, "<details class=\"tf\" id=\"c.any.js\" data-gate=\"none-passed\"");
    try expectHas(nodes, "<span class=\"gate gate-none-passed g-block\">NONE-PASSED</span>");

    const url = try readOut(gpa, &f, "out/url/index.html");
    defer gpa.free(url);
    try expectHas(url, "<details class=\"tf\" id=\"never.html\" data-gate=\"unrun\"");
    try expectHas(url, "<span class=\"tf-n\"><span class=\"quiet\">&mdash;</span><span class=\"tf-lbl\"> not run</span></span>");
    try expectHas(url, "It has no result yet.");
}

test "site: a test file's section lists its subtests, failures opening in place, passing ones named under their count" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    // a.html and c.any.js have detail; b.html's only stream line is in a
    // stream from another run, which must not be used.
    try testing.expectEqual(@as(usize, 2), s.detail_files);

    const dom = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(dom);
    const a = dom[std.mem.indexOf(u8, dom, "id=\"a.html\"").?..std.mem.indexOf(u8, dom, "id=\"b.html\"").?];
    // The subtest that failed, with its id, opening in place to its message.
    try expectHas(a, "<details><summary><span class=\"mark\">FAIL</span><span class=\"sub-name\">two &lt;b&gt;&amp;</span></summary><pre class=\"msg\">assert_equals: expected 1 but got 2</pre></details>");
    try expectHas(a, "<li class=\"sub s-fail\" id=\"s-");
    // The two that passed: counted, and named in the harness's order under the count.
    try expectHas(a, "<details class=\"passing\"><summary>2 passing subtests</summary><ol class=\"pass-list\"><li>one</li><li>three</li></ol></details>");
    try testing.expect(std.mem.indexOf(u8, a, "s-pass") == null);
    try expectHas(a, "https://github.com/zig-whatwg/wpt/blob/50d8c16fa8219824aad90ef0ec02328e7ecbc8e5/dom/a.html");
    // Its run is the generation's main one, which the index names: not here.
    try testing.expect(std.mem.indexOf(u8, dom, "sweep-abc1234") == null);
    try testing.expect(std.mem.indexOf(u8, dom, "<dt>Run</dt>") == null);

    // Two runs of c.any.js, each under its test URL, sorted.
    const c = try readOut(gpa, &f, "out/dom/nodes/index.html");
    defer gpa.free(c);
    try expectBefore(c, "<code>/dom/nodes/c.any.html</code>", "<code>/dom/nodes/c.any.worker.html</code>");

    const b = dom[std.mem.indexOf(u8, dom, "id=\"b.html\"").?..];
    try expectHas(b, "No per-subtest data for this file.");
    try testing.expect(std.mem.indexOf(u8, b, "stale") == null);
    try expectHas(b, "<pre class=\"msg\">took too long</pre>");

    // url/u.html's result came from another run than the main one: its section names it.
    const url = try readOut(gpa, &f, "out/url/index.html");
    defer gpa.free(url);
    try expectHas(url, "<div><dt>Run</dt><dd><code>other/journal.shard0</code>");
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    try expectHas(index, "<code>sweep-abc1234</code> (3 files, <a href=\"https://github.com/zig-whatwg/crane/commit/abc1234\"><code>abc1234</code></a>");
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

    const a = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(a);
    try testing.expectEqual(@as(usize, 6), std.mem.count(u8, a, "<li class=\"sub s-fail\""));
    try testing.expectEqual(@as(usize, 0), std.mem.count(u8, a, "<li class=\"sub s-pass\""));
    try testing.expect(std.mem.indexOf(u8, a, "pass-list") == null);
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
        // Every page is a whole document with its numbers in it (but the
        // 404 page, which carries no results, so it never changes).
        try testing.expect(std.mem.startsWith(u8, page, "<!doctype html>\n"));
        try testing.expect(std.mem.endsWith(u8, page, "</html>\n"));
        if (!std.mem.eql(u8, e.path, "404.html")) try expectHas(page, "WPT subtests passing");
    }
    // index.html, three directory pages and 404.html.
    try testing.expectEqual(@as(usize, 5), pages);
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
        .{ "out/404.html", "<script src=\"/crane/site.js\" defer></script>" },
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
    try expectHas(dom, "<details class=\"tf\" id=\"b.html\" data-gate=\"timeout\" data-pass=\"0\" data-of=\"0\" data-failed=\"0\">");
    // a.html: 2 of 3 passing, 1 failed.
    try expectHas(dom, "<details class=\"tf\" id=\"a.html\" data-gate=\"partial\" data-pass=\"2\" data-of=\"3\" data-failed=\"1\">");
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

test "site: a file that leaves the worklist loses its section; an old test file page is removed; .git is never touched" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/.git", .data = "gitdir: elsewhere\n" });
    try f.tmp.dir.createDirPath(testing.io, "out/data/dirs");
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/data/dirs/dom.json", .data = "{}" });
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/site.js", .data = "old" });
    // A test file's page as the site wrote them until 2026-11-07.
    try f.tmp.dir.createDirPath(testing.io, "out/dom/b.html");
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/dom/b.html/index.html", .data = "<!doctype html>old" });
    const smaller =
        \\dom/b.html
        \\url/u.html
        \\
    ;
    const s = try runFixture(gpa, &f, "out", smaller);
    // dom/nodes/index.html, the old file page, data/dirs/dom.json and site.js.
    try testing.expectEqual(@as(usize, 4), s.removed);
    try testing.expect(!exists(&f, "out/dom/nodes/index.html"));
    try testing.expect(!exists(&f, "out/dom/nodes"));
    const dom = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(dom);
    try testing.expect(std.mem.indexOf(u8, dom, "id=\"a.html\"") == null);
    try expectHas(dom, "id=\"b.html\"");
    // The old file page goes, with its directory.
    try testing.expect(!exists(&f, "out/dom/b.html/index.html"));
    try testing.expect(!exists(&f, "out/dom/b.html"));
    // The script-rendered site's leftovers go too.
    try testing.expect(!exists(&f, "out/data/dirs/dom.json"));
    try testing.expect(!exists(&f, "out/site.js"));
    try testing.expect(exists(&f, "out/.git"));
    try testing.expect(exists(&f, "out/.nojekyll"));
}

test "site: /performance/ is perf_bench's: a regeneration leaves it alone and never stages it" {
    // tools/perf_bench writes performance/ into the same gh-pages tree
    // (docs/performance.md): this generator neither prunes it (it did not
    // write it) nor sweeps it into a WPT generation's commit.
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    try f.tmp.dir.createDirPath(testing.io, "out/performance");
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/performance/index.html", .data = "<!doctype html>perf" });
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/performance/card.png", .data = "png" });
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    try testing.expectEqual(@as(usize, 0), s.removed);
    try testing.expect(exists(&f, "out/performance/index.html"));
    try testing.expect(exists(&f, "out/performance/card.png"));
    // The commit stages everything but performance/.
    try testing.expectEqualStrings(":(exclude)" ++ performance_dir, stage_argv[stage_argv.len - 1]);
}

test "site: /frameworks/ is fw_matrix's: a regeneration leaves it alone and never stages it" {
    // tools/fw_matrix's report (the JS framework compatibility matrix) is
    // published into the same gh-pages tree as /frameworks/, as
    // perf_bench's /performance/ is.
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    try f.tmp.dir.createDirPath(testing.io, "out/frameworks/react");
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/frameworks/index.html", .data = "<!doctype html>matrix" });
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/frameworks/react/index.html", .data = "<!doctype html>react" });
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    try testing.expectEqual(@as(usize, 0), s.removed);
    try testing.expect(exists(&f, "out/frameworks/index.html"));
    try testing.expect(exists(&f, "out/frameworks/react/index.html"));
    var excluded = false;
    for (stage_argv) |a| excluded = excluded or std.mem.eql(u8, a, ":(exclude)" ++ frameworks_dir);
    try testing.expect(excluded);
}

test "site: the index links to /performance/" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    try expectHas(index, "<div><dt>Performance</dt><dd><a href=\"performance/\">");
    // Only the index: the frame every page carries stays as it was.
    const page = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(page);
    try testing.expect(std.mem.indexOf(u8, page, "performance/") == null);
}

test "site: the index links to /frameworks/, beside /performance/" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    // The JS framework compatibility matrix (tools/fw_matrix), right after
    // the benchmark report's line.
    try expectHas(index, "</a></dd></div>\n<div><dt>Frameworks</dt><dd><a href=\"frameworks/\">");
    const page = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(page);
    try testing.expect(std.mem.indexOf(u8, page, "frameworks/") == null);
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
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    try testing.expectEqualStrings("lane/serializable", (try mergeName(a, "Merge lane/serializable (d6a770df64): [Serializable] platform objects")).?);
    try testing.expectEqualStrings("infra/test-aggregation", (try mergeName(a, "Merge infra/test-aggregation (f476a8c834): one test executable")).?);
    try testing.expectEqualStrings("lane/x", (try mergeName(a, "Merge branch 'lane/x' into main")).?);
    try testing.expectEqualStrings("origin/main", (try mergeName(a, "Merge remote-tracking branch 'origin/main' into crane-upstream")).?);
    try testing.expectEqualStrings("fix/retire-oom", (try mergeName(a, "Merge fix/retire-oom")).?);
    try testing.expect((try mergeName(a, "chore: codex-indexeddb's Crane tests (gitlink)")) == null);
    try testing.expect((try mergeName(a, "Merge ")) == null);
}

test "range: the integrator's merge subjects name the lane, and a merge of main is main" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    // Every form in `git log --first-parent --merges -30 main` (2026-11-09, at
    // afa8760139d), each subject as the integrator wrote it, cut after its sha.
    const cases = [_]struct { []const u8, []const u8 }{
        // "Merge lane <name> batch <n> (<sha>; ...): ..."
        .{ "lane/flaky7", "Merge lane flaky7 batch 1 (372282a168f; A/B runner tip-81be8a6d70a): the recurring flakes" },
        .{ "lane/perf2", "Merge lane perf2 batch 8 (1cadff0885e; A/B tip ec96867fc8b): the byte-by-byte breakdown" },
        // A batch with its plan's item first in the parentheses.
        .{ "lane/perf3", "Merge lane perf3 batch 5 (E1, 1fc9dbe49af; A/B tip 23fbd4a2df4): the custom element registry" },
        // A batch named with its item after an equals sign.
        .{ "lane/perf3", "Merge lane perf3 batch 3 = D1 (562964dd0c5; code fb6591d926a): an element's attributes out of line" },
        // "Merge lane <name> (<sha>): ..." - a lane's only batch.
        .{ "lane/site1", "Merge lane site1 (ecf3940136e): the WPT results site without per-test-file pages" },
        .{ "lane/perfpage", "Merge lane perfpage (8f4ea1752e4): /performance/'s Progress section" },
        // git's own subject for main merged into the integration branch.
        .{ "main", "Merge branch 'main' into lane/integrate" },
        // The integrator's subjects for the same: main at a commit, with or without a target.
        .{ "main", "Merge main dc6eeeaecef (generation 207's flake disposition) into lane/integrate" },
        .{ "main", "Merge main cc3ae79cf6a (generation 196's dispositions)" },
        .{ "main", "Merge main (lesson: a worklist change is a code change)" },
    };
    for (cases) |c| {
        const got = (try mergeName(a, c[1])) orelse {
            std.debug.print("no name for \"{s}\"\n", .{c[1]});
            return error.TestUnexpectedNull;
        };
        testing.expectEqualStrings(c[0], got) catch |e| {
            std.debug.print("subject: {s}\n", .{c[1]});
            return e;
        };
    }
    // A bare "Merge lane" names no lane: the word itself, as before.
    try testing.expectEqualStrings("lane", (try mergeName(a, "Merge lane")).?);
    // A merged name never holds a space: the history row's data-landed is a
    // space-separated list (site.js splits it).
    for (cases) |c| try testing.expect(std.mem.indexOfScalar(u8, (try mergeName(a, c[1])).?, ' ') == null);
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
    try expectHas(index, "<a href=\"dom/nodes/#c.any.js\"><code>dom/nodes/c.any.js</code></a> <span class=\"gate gate-exempt\">Exempt</span>");
    try expectHas(index, "all three browsers keep the old behaviour on purpose");
    try expectHas(index, "<dt>Chrome</dt><dd>wpt.fyi run 6218298311311360: 0/2; intent: <a href=\"https://issues.chromium.org/issues/11\">");
    try expectHas(index, "<dt>Firefox</dt><dd>wpt.fyi run 4877098740350976: 0/2; intent: <a href=\"https://bugzilla.mozilla.org/show_bug.cgi?id=22\">");
    try expectHas(index, "<dt>Safari</dt><dd>wpt.fyi run 5164107446878208: 0/2; intent: <a href=\"https://github.com/WebKit/standards-positions/issues/33\">");
    // A listed file that does not block keeps its standing.
    try expectHas(index, "<a href=\"url/#u.html\"><code>url/u.html</code></a> <span class=\"gate gate-clean\">Clean</span>");
    try expectHas(index, "Not counted among them: 1 file that would block is <a href=\"#exempt\">exempt</a>");

    // The file's own section says so, with the evidence, and its directory
    // counts it as exempt, not blocking.
    const dir = try readOut(gpa, &f, "out/dom/nodes/index.html");
    defer gpa.free(dir);
    try expectHas(dir, "<span class=\"gate gate-exempt\">Exempt</span>");
    try expectHas(dir, "Exempt from the 0.1 gate");
    try expectHas(dir, "https://github.com/WebKit/standards-positions/issues/33");
    try testing.expect(std.mem.indexOf(u8, dir, "Blocking files</dt><dd>1") == null);
    try expectHas(dir, "<details class=\"tf\" id=\"c.any.js\" data-gate=\"exempt\"");
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

fn fixtureTestBug(comptime path: []const u8) []const u8 {
    return "[" ++ path ++ "]\n" ++
        \\kind = test-bug
        \\why = the test posts a platform object, which structured clone rejects in every engine
        \\upstream = https://github.com/web-platform-tests/wpt/issues/99999
        \\chrome.result = wpt.fyi run 5070179567140864: 0/2
        \\firefox.result = wpt.fyi run 5140459022974976: 0/2
        \\safari.result = wpt.fyi run 5107094106406912: 0/2
        \\revisit = when https://github.com/web-platform-tests/wpt/issues/99999 is resolved
        \\
    ;
}

test "site: a test-bug exemption is its own group, with its upstream issue, never blocking" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    // b.html (TIMEOUT) intentional, c.any.js (NONE-PASSED) a test bug: neither blocks.
    const text = comptime fixtureExemption("dom/b.html") ++ fixtureTestBug("dom/nodes/c.any.js");
    _ = try runFixtureExempt(gpa, &f, "kinds", text, &diag);

    const index = try readOut(gpa, &f, "kinds/index.html");
    defer gpa.free(index);
    // (A zero is not marked as blocking: no class.)
    try expectHas(index, "<div><dt>Blocking files</dt><dd>0</dd>");
    // The conformance box counts both as exempt.
    try expectHas(index, "<dt><span class=\"key key-exempt\"></span>Exempt</dt><dd>2</dd>");
    // Two groups, each under its own heading, after the status and before the contents.
    try expectBefore(index, "id=\"status\"", "id=\"exempt\"");
    try expectBefore(index, "id=\"exempt\"", "id=\"exempt-test-bug\"");
    try expectBefore(index, "id=\"exempt-test-bug\"", "id=\"contents\"");
    try expectHas(index, "<h2 id=\"exempt-h\">Exempt from the gate</h2>");
    try expectHas(index, "<h2 id=\"exempt-test-bug-h\">Exempt until an upstream test bug is fixed</h2>");
    // The intentional group holds b.html only; the test-bug group c.any.js, with
    // the upstream link, every browser's result and when to revisit.
    const bug_at = std.mem.indexOf(u8, index, "id=\"exempt-test-bug\"").?;
    const intentional = index[std.mem.indexOf(u8, index, "id=\"exempt\"").?..bug_at];
    try expectHas(intentional, "<a href=\"dom/#b.html\"><code>dom/b.html</code></a> <span class=\"gate gate-exempt\">Exempt</span>");
    try testing.expect(std.mem.indexOf(u8, intentional, "c.any.js") == null);
    const bug = index[bug_at..std.mem.indexOf(u8, index, "id=\"contents\"").?];
    try expectHas(bug, "<a href=\"dom/nodes/#c.any.js\"><code>dom/nodes/c.any.js</code></a> <span class=\"gate gate-exempt\">Exempt</span>");
    try expectHas(bug, "the test posts a platform object, which structured clone rejects in every engine");
    try expectHas(bug, "<dt>Upstream</dt><dd><a href=\"https://github.com/web-platform-tests/wpt/issues/99999\">https://github.com/web-platform-tests/wpt/issues/99999</a></dd>");
    try expectHas(bug, "<dt>Chrome</dt><dd>wpt.fyi run 5070179567140864: 0/2</dd>");
    try expectHas(bug, "<dt>Firefox</dt><dd>wpt.fyi run 5140459022974976: 0/2</dd>");
    try expectHas(bug, "<dt>Safari</dt><dd>wpt.fyi run 5107094106406912: 0/2</dd>");
    try expectHas(bug, "<dt>Revisit</dt><dd>when https://github.com/web-platform-tests/wpt/issues/99999 is resolved</dd>");
    try testing.expect(std.mem.indexOf(u8, bug, "intent:") == null);
    try testing.expect(std.mem.indexOf(u8, bug, "dom/b.html") == null);
    // The status counts each group on its own, and links each.
    try expectHas(index, "Not counted among them: 1 file that would block is <a href=\"#exempt\">exempt</a>, because all three of Chrome, Firefox and Safari intentionally deviate from the spec they test.");
    try expectHas(index, " Nor is 1 file that would block, <a href=\"#exempt-test-bug\">exempt until an upstream test bug is fixed</a>: Chrome, Firefox and Safari fail it identically because of a bug in the test, filed with web-platform-tests.");
    try expectHas(index, "<dd>would block, but all three browsers intentionally deviate from the spec it tests, or fail it identically because of a test bug filed upstream</dd>");

    // The file's own section says which kind, with its evidence.
    const dir = try readOut(gpa, &f, "kinds/dom/nodes/index.html");
    defer gpa.free(dir);
    try expectHas(dir, "<p class=\"note-label\">Exempt from the 0.1 gate until an upstream test bug is fixed</p>");
    try expectHas(dir, "<dt>Upstream</dt><dd><a href=\"https://github.com/web-platform-tests/wpt/issues/99999\">");
    try expectHas(dir, "<details class=\"tf\" id=\"c.any.js\" data-gate=\"exempt\"");
    const dom = try readOut(gpa, &f, "kinds/dom/index.html");
    defer gpa.free(dom);
    try expectHas(dom, "<p class=\"note-label\">Exempt from the 0.1 gate</p>");
}

test "site: test-bug exemptions alone write only their own group" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    _ = try runFixtureExempt(gpa, &f, "bugonly", fixtureTestBug("dom/nodes/c.any.js"), &diag);
    const index = try readOut(gpa, &f, "bugonly/index.html");
    defer gpa.free(index);
    try testing.expect(std.mem.indexOf(u8, index, "id=\"exempt\"") == null);
    try expectHas(index, "id=\"exempt-test-bug\"");
    try expectHas(index, "Not counted among them: 1 file that would block is <a href=\"#exempt-test-bug\">exempt until an upstream test bug is fixed</a>: Chrome, Firefox and Safari fail it identically because of a bug in the test, filed with web-platform-tests.");
    try expectHas(index, "<dd>would block, but all three browsers fail it identically because of a test bug filed upstream</dd>");
    try testing.expect(std.mem.indexOf(u8, index, "intentionally deviate") == null);
}

test "site: an invalid test-bug exemption stops the site" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    // Not identical in all three browsers.
    const uneven = comptime blk: {
        const full = fixtureTestBug("dom/nodes/c.any.js");
        const at = std.mem.indexOf(u8, full, "5107094106406912: 0/2").?;
        break :blk full[0..at] ++ "5107094106406912: 2/2" ++ full[at + "5107094106406912: 0/2".len ..];
    };
    try testing.expectError(error.InvalidExemption, runFixtureExempt(gpa, &f, "bad-bug", uneven, &diag));
    try testing.expect(std.mem.indexOf(u8, diag.message, "the same result in all three browsers") != null);
}

fn fixtureNeedsRenderer(comptime path: []const u8) []const u8 {
    return "[" ++ path ++ "]\n" ++
        \\kind = needs-renderer
        \\why = decodeImageData reads the image back with getImageData(0, 0, img.clientWidth, img.clientHeight); with no renderer clientWidth is 0, so getImageData throws IndexSizeError
        \\assertion = promise_test: Unhandled rejection with value: object IndexSizeError
        \\
    ;
}

test "site: a needs-renderer exemption is its own group, with its failing assertion, never blocking" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    // b.html (TIMEOUT) a test bug, c.any.js (NONE-PASSED) needs a renderer: neither blocks.
    const text = comptime fixtureTestBug("dom/b.html") ++ fixtureNeedsRenderer("dom/nodes/c.any.js");
    _ = try runFixtureExempt(gpa, &f, "renderer", text, &diag);

    const index = try readOut(gpa, &f, "renderer/index.html");
    defer gpa.free(index);
    try expectHas(index, "<div><dt>Blocking files</dt><dd>0</dd>");
    try expectHas(index, "<dt><span class=\"key key-exempt\"></span>Exempt</dt><dd>2</dd>");
    // Its own group, after the test-bug group and before the contents.
    try expectBefore(index, "id=\"exempt-test-bug\"", "id=\"exempt-needs-renderer\"");
    try expectBefore(index, "id=\"exempt-needs-renderer\"", "id=\"contents\"");
    try expectHas(index, "<h2 id=\"exempt-needs-renderer-h\">Exempt until a renderer answers geometry</h2>");
    const at = std.mem.indexOf(u8, index, "id=\"exempt-needs-renderer\"").?;
    const bug = index[std.mem.indexOf(u8, index, "id=\"exempt-test-bug\"").?..at];
    try testing.expect(std.mem.indexOf(u8, bug, "c.any.js") == null);
    const group = index[at..std.mem.indexOf(u8, index, "id=\"contents\"").?];
    try expectHas(group, "<a href=\"dom/nodes/#c.any.js\"><code>dom/nodes/c.any.js</code></a> <span class=\"gate gate-exempt\">Exempt</span>");
    try expectHas(group, "decodeImageData reads the image back with getImageData(0, 0, img.clientWidth, img.clientHeight)");
    try expectHas(group, "<dt>Failing assertion</dt><dd>promise_test: Unhandled rejection with value: object IndexSizeError</dd>");
    try testing.expect(std.mem.indexOf(u8, group, "dom/b.html") == null);
    try testing.expect(std.mem.indexOf(u8, group, "<dt>Upstream</dt>") == null);
    // The status counts it on its own, and links its group; the legend names it.
    try expectHas(index, " Nor is 1 file that would block, <a href=\"#exempt-needs-renderer\">exempt until a renderer answers geometry</a>: it fails only because Crane has no renderer to answer geometry (a layout box&rsquo;s size or position).");
    try expectHas(index, "<dd>would block, but all three browsers fail it identically because of a test bug filed upstream, or it fails only because no renderer answers geometry</dd>");

    // The file's own section says which kind, with its assertion.
    const dir = try readOut(gpa, &f, "renderer/dom/nodes/index.html");
    defer gpa.free(dir);
    try expectHas(dir, "<p class=\"note-label\">Exempt from the 0.1 gate until a renderer answers geometry</p>");
    try expectHas(dir, "<dt>Failing assertion</dt><dd>promise_test: Unhandled rejection with value: object IndexSizeError</dd>");
    try expectHas(dir, "<details class=\"tf\" id=\"c.any.js\" data-gate=\"exempt\"");
}

test "site: needs-renderer exemptions alone write only their own group" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    _ = try runFixtureExempt(gpa, &f, "rendereronly", fixtureNeedsRenderer("dom/nodes/c.any.js"), &diag);
    const index = try readOut(gpa, &f, "rendereronly/index.html");
    defer gpa.free(index);
    try testing.expect(std.mem.indexOf(u8, index, "id=\"exempt\"") == null);
    try testing.expect(std.mem.indexOf(u8, index, "id=\"exempt-test-bug\"") == null);
    try expectHas(index, "id=\"exempt-needs-renderer\"");
    try expectHas(index, "Not counted among them: 1 file that would block is <a href=\"#exempt-needs-renderer\">exempt until a renderer answers geometry</a>: it fails only because Crane has no renderer to answer geometry (a layout box&rsquo;s size or position).");
    try expectHas(index, "<dd>would block, but it fails only because no renderer answers geometry</dd>");
    try testing.expect(std.mem.indexOf(u8, index, "all three browsers") == null);
}

test "site: an invalid needs-renderer exemption stops the site" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    const no_assertion = comptime blk: {
        const full = fixtureNeedsRenderer("dom/nodes/c.any.js");
        break :blk full[0..std.mem.indexOf(u8, full, "assertion =").?];
    };
    try testing.expectError(error.InvalidExemption, runFixtureExempt(gpa, &f, "bad-renderer", no_assertion, &diag));
    try testing.expect(std.mem.indexOf(u8, diag.message, "missing \"assertion\"") != null);
}

// Generations whose results came from runs named in the history: generation 3's
// largest run is its sweep, beside a smaller targeted run.
const fixture_history_hosts =
    \\{"gate_rule":2,"generations":[
    \\{"n":1,"at":"2026-09-19T19:55:00","head":"?","reconstructed":true,"total":5,"run":2,"unrun":3,"blocking":1,"crash":0,"timeout":1,"error":0,"clean":1,"partial":0,"sub_pass":3,"sub_fail":0,"sub_passing":3,"sub_targeted":6},
    \\{"n":2,"at":"2026-09-30T11:21:23","head":"5c8dd64da","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3,"sub_passing":5,"sub_targeted":8,"subs":{"passed":5,"failed":3,"timed_out":0,"notrun":0},"sources":[{"label":"sweep-5c8dd64da","journal":"journal.jsonl","commit":"5c8dd64da","files":4,"moved":2}]},
    \\{"n":3,"at":"2026-10-01T09:00:00","head":"6d9ee75eb","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3,"sub_passing":5,"sub_targeted":8,"subs":{"passed":5,"failed":3,"timed_out":0,"notrun":0},"sources":[{"label":"main-6d9ee75eb-dom","journal":"journal.jsonl","commit":null,"files":1,"moved":1},{"label":"sweep-6d9ee75eb","journal":"journal.jsonl","commit":"6d9ee75eb","files":4,"moved":0}]}
    \\],"last_statuses":{}}
;

fn runFixtureHosts(gpa: Allocator, f: *Fixture, out_name: []const u8, history: []const u8, hosts: []const u8, diag: *model.ExemptionDiag) !Summary {
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, out_name, .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    return generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = history,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
        .hosts_text = hosts,
        .hosts_diag = diag,
    }, out);
}

test "site: each generation says where it was swept: host, OS and runners" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    const hosts =
        \\# label host os-arch runners
        \\sweep-5c8dd64da chat.local macos-arm64 8
        \\sweep-6d9ee75eb server1 linux-x86_64 32
        \\main-6d9ee75eb-dom chat2.local macos-arm64 4
        \\
    ;
    _ = try runFixtureHosts(gpa, &f, "hosts", fixture_history_hosts, hosts, &diag);
    const index = try readOut(gpa, &f, "hosts/index.html");
    defer gpa.free(index);
    // The generation entry: the latest generation's largest run, its sweep.
    try expectHas(index, "<div><dt>Swept on</dt><dd><code>server1</code>, Linux x86-64, 32 runners</dd></div>");
    try expectBefore(index, "<dt>Runs</dt>", "<dt>Swept on</dt>");
    // Each history row: a column, and the words for the chart's readout.
    try expectHas(index, "<th scope=\"col\">Flaky files</th><th scope=\"col\">Swept on</th>");
    try expectHas(index, "data-swept=\"server1 (Linux x86-64, 32 runners)\"");
    try expectHas(index, "data-swept=\"chat.local (macOS arm64, 8 runners)\"");
    try expectHas(index, "<td class=\"host\"><code>server1</code> <small class=\"dim\">Linux x86-64, 32 runners</small></td></tr>");
    try expectHas(index, "<td class=\"host\"><code>chat.local</code> <small class=\"dim\">macOS arm64, 8 runners</small></td></tr>");
    // A generation with no run named (reconstructed): not known.
    try expectHas(index, "<td class=\"host\">&mdash;</td></tr>");
    // The smaller targeted run of generation 3 is not where it was swept.
    try testing.expect(std.mem.indexOf(u8, index, "chat2.local") == null);
}

test "site: no hosts write the same bytes as before; a latest generation not listed says so" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    _ = try runFixtureHosts(gpa, &f, "nohosts", fixture_history, "", &diag);
    _ = try runFixtureHosts(gpa, &f, "commented", fixture_history, "# no lines yet\n", &diag);
    _ = try runFixture(gpa, &f, "before", fixture_worklist);
    const a = try readOut(gpa, &f, "before/index.html");
    defer gpa.free(a);
    const b = try readOut(gpa, &f, "nohosts/index.html");
    defer gpa.free(b);
    const c = try readOut(gpa, &f, "commented/index.html");
    defer gpa.free(c);
    try testing.expectEqualStrings(a, b);
    try testing.expectEqualStrings(a, c);
    try testing.expect(std.mem.indexOf(u8, a, "Swept on") == null);

    // Hosts are listed, but not the latest generation's run.
    _ = try runFixtureHosts(gpa, &f, "unlisted", fixture_history_hosts, "sweep-5c8dd64da chat.local macos-arm64 8\n", &diag);
    const d = try readOut(gpa, &f, "unlisted/index.html");
    defer gpa.free(d);
    try expectHas(d, "<div><dt>Swept on</dt><dd>not recorded for this generation</dd></div>");
    try expectHas(d, "<td class=\"host\"><code>chat.local</code> <small class=\"dim\">macOS arm64, 8 runners</small></td></tr>");
}

test "site: an invalid hosts line stops the site" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    try testing.expectError(error.InvalidHosts, runFixtureHosts(gpa, &f, "badhosts", fixture_history_hosts, "sweep-6d9ee75eb server1 linux 32\n", &diag));
    try testing.expectEqual(@as(usize, 1), diag.line);
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
    return runFixtureRefHistory(gpa, f, out_name, ref_json, fixture_history);
}

fn runFixtureRefHistory(gpa: Allocator, f: *Fixture, out_name: []const u8, ref_json: ?[]const u8, history_json: []const u8) !Summary {
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, out_name, .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    return generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = history_json,
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
    // Side by side over the files both ran (url/never.html is Chrome's alone):
    // subtests passing of reported, and blocking files, for both.
    try expectHas(index, "<span class=\"box-sub\">4 test files both ran</span>");
    try expectHas(index, "<tr><th scope=\"row\">WPT subtests passing</th><td class=\"n\" data-v=\"5\" data-of=\"8\"><b>5</b> / 8</td><td class=\"n\" data-v=\"7\" data-of=\"9\"><b>7</b> / 9</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Blocking files</th><td class=\"n blk\">2</td><td class=\"n\">0</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Clean files</th><td class=\"n\">1</td><td class=\"n\">3</td></tr>");
    try expectHas(index, "Not compared: <a href=\"chrome.html#only-one\">1 file</a> with a result from Chrome alone, 0 from Crane alone.");
    try expectHas(index, "ran the worklist&rsquo;s 5 test files");
    // The Crane runner the window timed beside it, by its frozen commit.
    try expectHas(index, "In the same window Crane&rsquo;s frozen runner, main <a href=\"https://github.com/zig-whatwg/crane/commit/0c228a97aa\"><code>0c228a97aa</code></a>, ran the same files with the same runners.");
    // Where they differ, both directions, on the comparison page.
    try expectHas(index, "<a href=\"chrome.html#ahead-ref\">3 files</a> where Chrome passes subtests Crane does not (4 subtests)");
    try expectHas(index, "<a href=\"chrome.html#ahead-crane\">1 file</a> where Crane passes subtests Chrome does not (2 subtests)");
    // The suite tables carry Chrome's count beside Crane's.
    try expectHas(index, "<th scope=\"col\" class=\"n\">Chrome</th>");

    // A directory page: Chrome's numbers for the directory, and per file.
    const dom = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(dom);
    try expectHas(dom, "<p class=\"figures-ref\"><span class=\"ref-name\">Chrome</span> <b>6</b> / 6 WPT subtests passing on the same files, <span class=\"quiet\">none blocking</span></p>");
    // Each file's row: Chrome's subtests passing beside Crane's.
    try expectHas(dom, "<details class=\"tf\" id=\"a.html\" data-gate=\"partial\" data-pass=\"2\" data-of=\"3\" data-failed=\"1\" data-ref-pass=\"3\" data-ref-of=\"3\">");
    try expectHas(dom, "<span class=\"tf-n\"><b>2</b> / 3<span class=\"tf-lbl\"> passing</span></span><span class=\"tf-ref\"><span class=\"tf-lbl\">Chrome </span><b>3</b> / 3</span>");
    try expectHas(dom, "<div class=\"tf-head\"><span>Test file</span><span>Subtests passing</span><span>Chrome</span><span>Failed</span><span>Standing</span></div>");

    // A file's section: Chrome's standing and count beside Crane's.
    try expectHas(dom, "<div><dt>Chrome</dt><dd><span class=\"gate gate-clean\">Clean</span> <b>1</b> / 1 WPT subtests passing <span class=\"quiet\">runner status <code>OK</code></span></dd></div>");
    const c = try readOut(gpa, &f, "out/dom/nodes/index.html");
    defer gpa.free(c);
    try expectHas(c, "1 of its test URLs has no Chrome result");
    const never = try readOut(gpa, &f, "out/url/index.html");
    defer gpa.free(never);
    try expectHas(never, "<details class=\"tf\" id=\"never.html\" data-gate=\"unrun\"");
    try expectHas(never, "<div><dt>Chrome</dt><dd><span class=\"gate gate-timeout g-block\">TIMEOUT</span> <b>1</b> / 2 WPT subtests passing");

    // The comparison page: Chrome ahead by most subtests first, then Crane ahead,
    // then the files only one of them ran.
    const cmp = try readOut(gpa, &f, "out/chrome.html");
    defer gpa.free(cmp);
    try expectBefore(cmp, "id=\"ahead-ref\"", "id=\"ahead-crane\"");
    try expectBefore(cmp, "id=\"ahead-crane\"", "id=\"only-one\"");
    try expectBefore(cmp, "<a href=\"dom/nodes/#c.any.js\">", "<a href=\"dom/#a.html\">");
    try expectBefore(cmp, "<a href=\"dom/#a.html\">", "<a href=\"dom/#b.html\">");
    try expectBefore(cmp, "<a href=\"dom/#b.html\">", "id=\"ahead-crane\"");
    try expectBefore(cmp, "id=\"ahead-crane\"", "<a href=\"url/#u.html\">");
    try expectBefore(cmp, "id=\"only-one\"", "<a href=\"url/#never.html\">");
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
    try expectHas(index, "CPU is the larger of what the run&rsquo;s harness waited for (rusage) and a once-a-second sample of its whole process tree");
    // A run that records no test count is read over the worklist's 7 test URLs.
    try expectHas(index, "<tr><th scope=\"row\">Of the wall clock: harness (estimate)</th><td class=\"n\">350 ms</td><td class=\"n\">2.10 s</td></tr>");

    // A run that ran 3 test URLs is split over those 3, and says what it ran.
    const partial = try std.mem.replaceOwned(u8, gpa, fixture_reference, "\"reference\":{\"wall_s\":3600.5,", "\"reference\":{\"tests\":3,\"wall_s\":3600.5,");
    defer gpa.free(partial);
    const partial2 = try std.mem.replaceOwned(u8, gpa, partial, "\"crane\":{\"wall_s\":2400,", "\"crane\":{\"tests\":3,\"wall_s\":2400,");
    defer gpa.free(partial2);
    const partial3 = try std.mem.replaceOwned(u8, gpa, partial2, "\"sources_reported\":5,", "\"sources_reported\":2,");
    defer gpa.free(partial3);
    _ = try runFixtureRef(gpa, &f, "out3", partial3);
    const index3 = try readOut(gpa, &f, "out3/index.html");
    defer gpa.free(index3);
    try expectHas(index3, "<tr><th scope=\"row\">Of the wall clock: harness (estimate)</th><td class=\"n\">150 ms</td><td class=\"n\">900 ms</td></tr>");
    try expectHas(index3, "has a result for 2 of the worklist&rsquo;s 5 test files");
}

test "site: each side's build is named, and the window's runs give pass counts, CPU and memory side by side" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const a = try std.mem.replaceOwned(u8, gpa, fixture_reference, "\"command\":\"wpt run chrome\",", "\"command\":\"wpt run chrome\",\"build\":\"Chrome for Testing, official release build\",");
    defer gpa.free(a);
    const b = try std.mem.replaceOwned(u8, gpa, a, "\"reference\":{\"wall_s\":3600.5,\"user_s\":9000,\"sys_s\":1200}", "\"reference\":{\"wall_s\":3600.5,\"user_s\":9000,\"sys_s\":1200,\"passed\":8,\"reported\":11,\"memory\":{\"samples\":3600,\"engine_peak_mb\":6144,\"engine_mean_mb\":3000.4,\"harness_peak_mb\":900,\"harness_mean_mb\":700,\"groups\":5,\"group_peak_max_mb\":1500,\"group_peak_mean_mb\":1200}}");
    defer gpa.free(b);
    const c = try std.mem.replaceOwned(u8, gpa, b, "\"files\":5,\"runner\":\"main-0c228a97aa\"}", "\"files\":5,\"runner\":\"release-0c228a97aa\",\"build\":\"release runner: ReleaseSafe throughout, libc malloc\",\"passed\":5,\"reported\":8,\"memory\":{\"samples\":2400,\"engine_peak_mb\":800,\"engine_mean_mb\":512,\"harness_peak_mb\":250.6,\"harness_mean_mb\":200,\"groups\":330,\"group_peak_max_mb\":400,\"group_peak_mean_mb\":150}}");
    defer gpa.free(c);
    _ = try runFixtureRef(gpa, &f, "out", c);
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    try expectHas(index, "<tr><th scope=\"row\">WPT subtests passing in this run</th><td class=\"n\"><b>5</b> / 8</td><td class=\"n\"><b>8</b> / 11</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Memory of the engine, peak</th><td class=\"n\">800 MB</td><td class=\"n\">6.0 GB</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Memory of the engine, mean</th><td class=\"n\">512 MB</td><td class=\"n\">2.9 GB</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Memory of the harness, peak</th><td class=\"n\">251 MB</td><td class=\"n\">900 MB</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">One runner&rsquo;s engine, largest peak</th><td class=\"n\">400 MB</td><td class=\"n\">1.5 GB</td></tr>");
    // Each side's build, named.
    try expectHas(index, "<dt>Chrome</dt><dd>Chrome for Testing <code>150.0.7000.1</code>: Chrome for Testing, official release build</dd>");
    try expectHas(index, "<dt>Crane</dt><dd>release runner: ReleaseSafe throughout, libc malloc");
    try expectHas(index, "no ThinLTO and no PGO");
    try expectHas(index, "phys_footprint");

    // The two V8s by version, and a reference run reused beside a later Crane run, said so.
    const d = try std.mem.replaceOwned(u8, gpa, c, "\"build\":\"Chrome for Testing, official release build\",", "\"build\":\"Chrome for Testing, official release build\",\"js_engine\":\"V8 15.7.1\",\"crane_js_engine\":\"V8 13.1.203\",");
    defer gpa.free(d);
    const e = try std.mem.replaceOwned(u8, gpa, d, "\"timing\":{\"processes\":5,", "\"timing\":{\"processes\":5,\"reference_reused\":\"the host and its load matched\",");
    defer gpa.free(e);
    _ = try runFixtureRef(gpa, &f, "out2", e);
    const index2 = try readOut(gpa, &f, "out2/index.html");
    defer gpa.free(index2);
    try expectHas(index2, "Crane links V8 <code>13.1.203</code>");
    try expectHas(index2, "Chrome <code>150.0.7000.1</code> ships V8 <code>15.7.1</code>");
    try expectHas(index2, "Chrome&rsquo;s figures are from its run of <span class=\"nowrap\">4 Nov 2026</span>, reused beside Crane&rsquo;s: the host and its load matched.");

    // On the official-style V8 (lane v8opt1), the V8 line says so instead of naming a gap.
    const official = try std.mem.replaceOwned(u8, gpa, e, "\"crane_js_engine\":\"V8 13.1.203\",", "\"crane_js_engine\":\"V8 13.1.203\",\"crane_v8_build\":\"official\",");
    defer gpa.free(official);
    _ = try runFixtureRef(gpa, &f, "out4", official);
    const index4 = try readOut(gpa, &f, "out4/index.html");
    defer gpa.free(index4);
    try expectHas(index4, "Crane links V8 <code>13.1.203</code>, built as Chrome&rsquo;s official build is: ThinLTO and PGO");
    try testing.expect(std.mem.indexOf(u8, index4, "no ThinLTO and no PGO") == null);

    // Before Crane's full run, its build is still named (its overhead runs are on the page).
    const g = try std.mem.replaceOwned(u8, gpa, fixture_reference, "\"command\":\"wpt run chrome\",", "\"command\":\"wpt run chrome\",\"crane_build\":\"release runner, overhead only\",");
    defer gpa.free(g);
    const h = try std.mem.replaceOwned(u8, gpa, g, "\"crane\":{\"wall_s\":2400,\"user_s\":8000,\"sys_s\":400,\"files\":5,\"runner\":\"main-0c228a97aa\"},", "");
    defer gpa.free(h);
    _ = try runFixtureRef(gpa, &f, "out3", h);
    const index3 = try readOut(gpa, &f, "out3/index.html");
    defer gpa.free(index3);
    try expectHas(index3, "<dt>Crane</dt><dd>release runner, overhead only</dd>");
    try expectHas(index3, "<tr><th scope=\"row\">The worklist, wall clock</th><td class=\"n\"><span class=\"quiet\">not measured</span></td>");
}

test "site: the wall time says where each pool's time goes, and the engine's memory without a runaway file stands beside the measured" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const a = try std.mem.replaceOwned(u8, gpa, fixture_reference, "\"reference\":{\"wall_s\":3600.5,\"user_s\":9000,\"sys_s\":1200}", "\"reference\":{\"wall_s\":3600.5,\"user_s\":9000,\"sys_s\":1200,\"pool\":{\"work_s\":1538.8},\"memory\":{\"samples\":3600,\"engine_peak_mb\":6144,\"engine_mean_mb\":3000.4,\"harness_peak_mb\":900,\"harness_mean_mb\":700,\"groups\":5,\"group_peak_max_mb\":1500,\"group_peak_mean_mb\":1200}}");
    defer gpa.free(a);
    const b = try std.mem.replaceOwned(u8, gpa, a, "\"files\":5,\"runner\":\"main-0c228a97aa\"}", "\"files\":5,\"runner\":\"main-0c228a97aa\",\"memory\":{\"samples\":2240,\"engine_peak_mb\":62353,\"engine_mean_mb\":1458,\"harness_peak_mb\":1058,\"harness_mean_mb\":1053,\"groups\":332,\"group_peak_max_mb\":62214,\"group_peak_mean_mb\":438},\"pool\":{\"work_s\":1347.8,\"chunks\":66,\"chunk_files\":200,\"shard_files\":40,\"barrier_s\":904.6,\"startup_s\":100.9},\"memory_without\":{\"path\":\"html/x/runaway.html\",\"note\":\"a runaway on main too, queued for a fix\",\"excluded\":\"its chunk\",\"engine_peak_mb\":1525,\"engine_mean_mb\":572}}");
    defer gpa.free(b);
    _ = try runFixtureRef(gpa, &f, "out", b);
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    // Beside the wall clock: the tests' own wall per runner, and what Crane's chunks lost; Chrome's one queue loses neither.
    try expectHas(index, "<tr><th scope=\"row\">The tests&rsquo; own wall clock, per runner</th><td class=\"n\">22 min 28 s</td><td class=\"n\">25 min 39 s</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Of the wall clock: waiting for a chunk&rsquo;s slowest runner</th><td class=\"n\">15 min 5 s</td><td class=\"n\"><span class=\"quiet\">none: one queue</span></td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Of the wall clock: chunk start-up</th><td class=\"n\">1 min 41 s</td><td class=\"n\"><span class=\"quiet\">none: one queue</span></td></tr>");
    try expectHas(index, "Crane&rsquo;s run went in 66 chunks of 200 files, each split into fixed shards of 40 files, one per runner; a chunk ends when its slowest shard does");
    try expectHas(index, "Chrome&rsquo;s <code>wptrunner</code> feeds its processes from one queue.");
    // The measured peak stays; the engine without the runaway file stands beside it, Chrome's own figures for comparison.
    try expectHas(index, "<tr><th scope=\"row\">Memory of the engine, peak</th><td class=\"n\">60.9 GB</td><td class=\"n\">6.0 GB</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Memory of the engine without the runaway file, peak</th><td class=\"n\">1.5 GB</td><td class=\"n\">6.0 GB</td></tr>");
    try expectHas(index, "<tr><th scope=\"row\">Memory of the engine without the runaway file, mean</th><td class=\"n\">572 MB</td><td class=\"n\">2.9 GB</td></tr>");
    try expectHas(index, "Crane&rsquo;s engine peak is one file, <code>html/x/runaway.html</code>: a runaway on main too, queued for a fix. The rows without the runaway file leave out its chunk; Chrome&rsquo;s are its whole run.");

    // A run that is one shared queue (lane sweepq1) waits for no chunk, and the page says so.
    const q = try std.mem.replaceOwned(u8, gpa, b, "\"pool\":{\"work_s\":1347.8,\"chunks\":66,\"chunk_files\":200,\"shard_files\":40,\"barrier_s\":904.6,\"startup_s\":100.9}", "\"pool\":{\"work_s\":1345.1,\"files_per_runner\":40}");
    defer gpa.free(q);
    _ = try runFixtureRef(gpa, &f, "out3", q);
    const queue = try readOut(gpa, &f, "out3/index.html");
    defer gpa.free(queue);
    try expectHas(queue, "<tr><th scope=\"row\">The tests&rsquo; own wall clock, per runner</th><td class=\"n\">22 min 25 s</td><td class=\"n\">25 min 39 s</td></tr>");
    try expectHas(queue, "<tr><th scope=\"row\">Of the wall clock: waiting for a chunk&rsquo;s slowest runner</th><td class=\"n\"><span class=\"quiet\">none: one queue</span></td><td class=\"n\"><span class=\"quiet\">none: one queue</span></td></tr>");
    try expectHas(queue, "Crane&rsquo;s run is one shared queue: each runner takes the next file when it is free, so no runner waits for another, and each runner process runs 40 files before a fresh one takes its place. The tests&rsquo; own wall clock is every file&rsquo;s summed over the 5 runners: what a pool that never waits would take. Chrome&rsquo;s <code>wptrunner</code> feeds its processes from one queue too.");
    try testing.expect(std.mem.indexOf(u8, queue, "chunks of") == null);

    // A window that measured neither shows neither.
    _ = try runFixtureRef(gpa, &f, "out2", fixture_reference);
    const plain = try readOut(gpa, &f, "out2/index.html");
    defer gpa.free(plain);
    try testing.expect(std.mem.indexOf(u8, plain, "own wall clock, per runner") == null);
    try testing.expect(std.mem.indexOf(u8, plain, "without the runaway file") == null);
}

// The latest generation's upstream WPT revisions (wpt_progress.py generation_upstream_fields; lane wptup1).
const fixture_history_upstreams =
    \\{"gate_rule":2,"generations":[
    \\{"n":2,"at":"2026-09-30T11:21:23","head":"5c8dd64da","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3,"sub_passing":5,"sub_targeted":8,
    \\"wpt_upstream":"2358bd48357992d5f3f9d6aaa2040aa018aaa093","reference_wpt_upstream":"afe89a5df4dcc7c6bcb317b07d6eee31a383c466"}
    \\],"last_statuses":{}}
;

test "site: after a WPT update the comparison says which upstream WPT revision Crane's column is on" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const note = "Crane&rsquo;s column is on upstream WPT <code>2358bd4835</code>, the reference&rsquo;s on <code>afe89a5df4</code>: a file that changed between the two revisions compares different tests.";
    _ = try runFixtureRefHistory(gpa, &f, "moved", fixture_reference, fixture_history_upstreams);
    const index = try readOut(gpa, &f, "moved/index.html");
    defer gpa.free(index);
    try expectHas(index, note);
    const page = try readOut(gpa, &f, "moved/chrome.html");
    defer gpa.free(page);
    try expectHas(page, note);
    // The same revision, or a history that records none: no sentence.
    const same = try std.mem.replaceOwned(u8, gpa, fixture_history_upstreams, "2358bd48357992d5f3f9d6aaa2040aa018aaa093", "afe89a5df4dcc7c6bcb317b07d6eee31a383c466");
    defer gpa.free(same);
    _ = try runFixtureRefHistory(gpa, &f, "same", fixture_reference, same);
    const index_same = try readOut(gpa, &f, "same/index.html");
    defer gpa.free(index_same);
    try testing.expect(std.mem.indexOf(u8, index_same, "column is on upstream WPT") == null);
    _ = try runFixtureRef(gpa, &f, "none", fixture_reference);
    const index_none = try readOut(gpa, &f, "none/index.html");
    defer gpa.free(index_none);
    try testing.expect(std.mem.indexOf(u8, index_none, "column is on upstream WPT") == null);
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
    const u = try readOut(gpa, &f, "out/url/index.html");
    defer gpa.free(u);
    try expectHas(u, "<details class=\"tf\" id=\"never.html\" data-gate=\"unrun\"");
    // Chrome's stream line beside Crane's journal is not Crane's detail.
    const dom = try readOut(gpa, &f, "out/dom/index.html");
    defer gpa.free(dom);
    const b = dom[std.mem.indexOf(u8, dom, "id=\"b.html\"").?..];
    try testing.expect(std.mem.indexOf(u8, b, "chrome&rsquo;s") == null);
    try testing.expect(std.mem.indexOf(u8, b, "chrome's") == null);
    try expectHas(b, "No per-subtest data for this file.");
    // reference/ is never named as a run.
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

// ============================================================================
// Tests: test files as sections of their directory's page (lane site1)
// ============================================================================

/// `href` resolved from the page at `page` (a path below the site root,
/// "dom/nodes/index.html"), as the site's own path and fragment; null for an
/// address outside the site.
fn resolveHref(buf: []u8, page: []const u8, href: []const u8) ?struct { path: []const u8, fragment: []const u8 } {
    if (std.mem.indexOf(u8, href, "://") != null or std.mem.startsWith(u8, href, "/") or std.mem.startsWith(u8, href, "data:")) return null;
    const hash = std.mem.indexOfScalar(u8, href, '#') orelse href.len;
    const fragment = if (hash < href.len) href[hash + 1 ..] else "";
    var segs: [64][]const u8 = undefined;
    var n: usize = 0;
    var dir_it = std.mem.splitScalar(u8, page[0..(std.mem.lastIndexOfScalar(u8, page, '/') orelse 0)], '/');
    while (dir_it.next()) |seg| if (seg.len > 0) {
        segs[n] = seg;
        n += 1;
    };
    var it = std.mem.splitScalar(u8, href[0..hash], '/');
    while (it.next()) |seg| {
        if (seg.len == 0 or std.mem.eql(u8, seg, ".")) continue;
        if (std.mem.eql(u8, seg, "..")) {
            if (n == 0) return null;
            n -= 1;
        } else {
            segs[n] = seg;
            n += 1;
        }
    }
    var len: usize = 0;
    for (segs[0..n]) |seg| {
        @memcpy(buf[len..][0..seg.len], seg);
        len += seg.len;
        buf[len] = '/';
        len += 1;
    }
    // A link to a directory is to its index.html; one ending in a file names it.
    const ends_dir = hash == 0 or href[hash - 1] == '/' or n == 0;
    if (!ends_dir) len -= 1 else {
        @memcpy(buf[len..][0.."index.html".len], "index.html");
        len += "index.html".len;
    }
    return .{ .path = buf[0..len], .fragment = fragment };
}

test "site: every link to a test file is its section on its directory's page, and lands there" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    var diag: model.ExemptionDiag = .{};
    const st = try f.state(gpa);
    defer gpa.free(st);
    var out = try f.tmp.dir.createDirPathOpen(testing.io, "out", .{ .open_options = .{ .iterate = true } });
    defer out.close(testing.io);
    // With a reference run (chrome.html) and an exemption (the index's exempt
    // group), so every page that links to test files is written.
    _ = try generate(gpa, testing.io, .{
        .state_json = st,
        .history_json = fixture_history,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
        .reference_json = fixture_reference,
        .exemptions_text = fixtureExemption("dom/nodes/c.any.js"),
        .exemption_diag = &diag,
    }, out);

    // Each page links to the files it shows by their sections.
    const index = try readOut(gpa, &f, "out/index.html");
    defer gpa.free(index);
    try expectHas(index, "<a href=\"dom/#a.html\">");
    try expectHas(index, "<a href=\"dom/nodes/#c.any.js\"><code>dom/nodes/c.any.js</code></a>");
    const cmp = try readOut(gpa, &f, "out/chrome.html");
    defer gpa.free(cmp);
    try expectHas(cmp, "<a href=\"url/#never.html\">");

    // Every link on every page lands on a page the site has, and every link
    // with a fragment on an element with that id - none on an old file page.
    var walker = try out.walk(gpa);
    defer walker.deinit();
    var file_links: usize = 0;
    while (try walker.next(testing.io)) |e| {
        if (e.kind != .file or !std.mem.endsWith(u8, e.path, ".html") or std.mem.eql(u8, e.path, "404.html")) continue;
        const page = try out.readFileAlloc(testing.io, e.path, gpa, .limited(1 << 24));
        defer gpa.free(page);
        var at: usize = 0;
        while (std.mem.indexOfPos(u8, page, at, "href=\"")) |i| {
            const start = i + "href=\"".len;
            const end = std.mem.indexOfScalarPos(u8, page, start, '"').?;
            at = end;
            const href = page[start..end];
            var buf: [512]u8 = undefined;
            const r = resolveHref(&buf, e.path, href) orelse continue;
            // Assets and the search's list are not pages; performance/ is
            // perf_bench's, frameworks/ fw_matrix's.
            if (!std.mem.endsWith(u8, r.path, ".html") or std.mem.startsWith(u8, r.path, performance_dir ++ "/") or std.mem.startsWith(u8, r.path, frameworks_dir ++ "/")) continue;
            const target = out.readFileAlloc(testing.io, r.path, gpa, .limited(1 << 24)) catch {
                std.debug.print("\n{s}: link {s} -> {s}, which the site does not have\n", .{ e.path, href, r.path });
                return error.TestBrokenLink;
            };
            defer gpa.free(target);
            if (r.fragment.len == 0) continue;
            if (std.mem.indexOfScalar(u8, r.fragment, '.') != null) file_links += 1;
            var idbuf: [300]u8 = undefined;
            const id = try std.fmt.bufPrint(&idbuf, "id=\"{s}\"", .{r.fragment});
            if (std.mem.indexOf(u8, target, id) == null) {
                std.debug.print("\n{s}: link {s} -> {s}, which has no {s}\n", .{ e.path, href, r.path, id });
                return error.TestBrokenLink;
            }
        }
    }
    try testing.expect(file_links >= 10);
}

test "site: 404.html sends a test file's old page address to its section" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    const nf = try readOut(gpa, &f, "out/404.html");
    defer gpa.free(nf);
    // Served at any missing address: its assets and home are named from the
    // site's own path, never relative to where it is served.
    try expectHas(nf, "<link rel=\"stylesheet\" href=\"/crane/site.css\">");
    try expectHas(nf, "<script src=\"/crane/site.js\" defer></script>");
    try expectHas(nf, "<li class=\"toc-suite\"><a href=\"/crane/dom/\">");
    try testing.expect(pages_mod.needsScript(nf) == null);
    // Its one relative link: a test file's old address's directory, for a
    // reader without script; site.js adds the file's #name and goes there.
    try expectHas(nf, "<a id=\"moved-to\" href=\"../\">");
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, nf, "href=\"../"));

    // Every test file's old address maps to its section: `../` of the old
    // address, then `#<name>` - and that section is there.
    const files = [_][]const u8{ "dom/a.html", "dom/b.html", "dom/nodes/c.any.js", "url/u.html", "url/never.html" };
    for (files) |p| {
        var oldbuf: [256]u8 = undefined;
        var tbuf: [256]u8 = undefined;
        const name = p[std.mem.lastIndexOfScalar(u8, p, '/').? + 1 ..];
        const dir = p[0 .. p.len - name.len];
        const old = try std.fmt.bufPrint(&oldbuf, "/crane/{s}/", .{p});
        const target = pages_mod.oldFileTarget(&tbuf, old).?;
        var want_buf: [256]u8 = undefined;
        try testing.expectEqualStrings(try std.fmt.bufPrint(&want_buf, "/crane/{s}#{s}", .{ dir, name }), target);
        var with_index: [256]u8 = undefined;
        var tbuf2: [256]u8 = undefined;
        try testing.expectEqualStrings(target, pages_mod.oldFileTarget(&tbuf2, try std.fmt.bufPrint(&with_index, "/crane/{s}/index.html", .{p})).?);
        // The plain link's rule: the old address's ../ is the section's page.
        var rbuf: [512]u8 = undefined;
        const r = resolveHref(&rbuf, old[1..], "../").?;
        var pbuf: [256]u8 = undefined;
        try testing.expectEqualStrings(try std.fmt.bufPrint(&pbuf, "crane/{s}index.html", .{dir}), r.path);
        var page_buf: [256]u8 = undefined;
        const page = try readOut(gpa, &f, try std.fmt.bufPrint(&page_buf, "out/{s}index.html", .{dir}));
        defer gpa.free(page);
        var idbuf: [256]u8 = undefined;
        try expectHas(page, try std.fmt.bufPrint(&idbuf, "<details class=\"tf\" id=\"{s}\"", .{name}));
    }
    // A directory's address, the site's own, and a page that exists are not
    // test files' old addresses.
    var buf: [256]u8 = undefined;
    try testing.expect(pages_mod.oldFileTarget(&buf, "/crane/dom/nodes/") == null);
    try testing.expect(pages_mod.oldFileTarget(&buf, "/crane/dom/index.html") == null);
    try testing.expect(pages_mod.oldFileTarget(&buf, "/crane/") == null);
}

/// fixture_stream, with dom/a.html given `n` passing subtests of long names
/// beside its failure, so its section's passing names weigh something.
fn heavyStream(gpa: Allocator, n: usize) ![]u8 {
    var s: std.ArrayList(u8) = .empty;
    errdefer s.deinit(gpa);
    try s.appendSlice(gpa, "{\"test\":\"/dom/a.html\",\"status\":\"OK\",\"message\":null,\"subtests\":[{\"name\":\"two\",\"status\":\"FAIL\",\"message\":\"assert_equals: expected 1 but got 2\"}");
    for (0..n) |i| try s.print(gpa, ",{{\"name\":\"a passing subtest whose name is long enough to weigh something on the page, number {d}\",\"status\":\"PASS\",\"message\":null}}", .{i});
    try s.appendSlice(gpa, "]}\n");
    const rest = fixture_stream[std.mem.indexOfScalar(u8, fixture_stream, '\n').? + 1 ..];
    try s.appendSlice(gpa, rest);
    return s.toOwnedSlice(gpa);
}

fn runBudget(gpa: Allocator, f: *Fixture, out_name: []const u8, bytes: usize) !Summary {
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
        .budget = .{ .bytes = bytes },
    }, out);
}

test "site: a directory page over its budget counts its passing subtests, and still over it splits into parts" {
    const gpa = testing.allocator;
    const stream = try heavyStream(gpa, 300);
    defer gpa.free(stream);
    var f = try Fixture.init(stream);
    defer f.deinit();

    // Within the budget: every passing subtest named.
    const all = try runBudget(gpa, &f, "all", pages_mod.Budget.default_bytes);
    try testing.expectEqual(@as(usize, 0), all.counted_pages);
    const named = try readOut(gpa, &f, "all/dom/index.html");
    defer gpa.free(named);
    try expectHas(named, "<details class=\"passing\"><summary>300 passing subtests</summary>");

    // One byte under it: dom/ counts them instead, and says so.
    const one = try runBudget(gpa, &f, "counted", named.len - 1);
    try testing.expect(one.counted_pages >= 1);
    try testing.expectEqual(@as(usize, 0), one.split_dirs);
    const counted = try readOut(gpa, &f, "counted/dom/index.html");
    defer gpa.free(counted);
    try testing.expect(counted.len <= named.len - 1);
    try testing.expect(std.mem.indexOf(u8, counted, "pass-list") == null);
    try expectHas(counted, "300 passing subtests, counted, not named on this page.");
    try expectHas(counted, "Passing subtests are counted, not named: with every name this page would be larger than");
    // The failure keeps its message.
    try expectHas(counted, "assert_equals: expected 1 but got 2");

    // Still over it: the sections go onto part pages, in name order; the
    // directory's page keeps every file's row, with its id, leading to its
    // part. (Well under the counted page: its note names the budget, so one
    // byte under it could fit once the note's number has a digit fewer.)
    const budget = counted.len - 500;
    const split = try runBudget(gpa, &f, "split", budget);
    try testing.expect(split.split_dirs >= 1);
    const dom = try readOut(gpa, &f, "split/dom/index.html");
    defer gpa.free(dom);
    try testing.expect(dom.len <= budget);
    try expectHas(dom, "<div class=\"tf tf-away\" id=\"a.html\" data-gate=\"partial\"");
    try expectHas(dom, "<a class=\"tf-row\" href=\"~1/#a.html\">");
    try expectHas(dom, "<a class=\"tf-row\" href=\"~2/#b.html\">");
    try expectHas(dom, "test files here, on 2 pages");
    try testing.expect(std.mem.indexOf(u8, dom, "<details class=\"tf\"") == null);
    const p1 = try readOut(gpa, &f, "split/dom/~1/index.html");
    defer gpa.free(p1);
    const p2 = try readOut(gpa, &f, "split/dom/~2/index.html");
    defer gpa.free(p2);
    try expectHas(p1, "<details class=\"tf\" id=\"a.html\"");
    try expectHas(p2, "<details class=\"tf\" id=\"b.html\"");
    try testing.expect(std.mem.indexOf(u8, p1, "id=\"b.html\"") == null);
    try expectHas(p1, "<link rel=\"stylesheet\" href=\"../../site.css\">");
    try expectHas(p2, "<li aria-current=\"page\">part 2 of 2</li>");
    try expectHas(p2, "<a href=\"../~1/\">Part 1</a>");
    // Each part holds one file here: two would not fit (a file is never cut).
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, p1, "<details class=\"tf\""));
    try testing.expectEqual(@as(usize, 1), std.mem.count(u8, p2, "<details class=\"tf\""));
    // The same input splits the same way: a rerun writes nothing.
    const again = try runBudget(gpa, &f, "split", budget);
    try testing.expectEqual(@as(usize, 0), again.written);
    // Back within the budget, the parts go.
    _ = try runBudget(gpa, &f, "split", pages_mod.Budget.default_bytes);
    try testing.expect(!exists(&f, "split/dom/~1/index.html"));
    try testing.expect(!exists(&f, "split/dom/~2"));
}

test "site: a directory page whose files' results did not move is byte-identical across a new generation and a new sweep" {
    // Generation 207's commit rewrote 13,206 pages for ~50 moved results: every
    // file page named its run, and every sweep is a new run.
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "one", fixture_worklist);

    // The next sweep: a new run, with the same results for dom/, and a
    // different one for url/u.html (from its own run, as before).
    try f.tmp.dir.createDirPath(testing.io, "results/sweep-def5678");
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "results/sweep-def5678/journal.shard1.jsonl", .data = "{}\n" });
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "results/sweep-def5678/journal.shard1.wptreport.jsonl", .data = fixture_stream });
    const st2 = try f.results.statFile(testing.io, "sweep-def5678/journal.shard1.jsonl", .{});
    const m2 = @as(f64, @floatFromInt(st2.mtime.nanoseconds)) / 1e9;
    const state2 = try std.fmt.allocPrint(gpa,
        \\{{"dom/a.html":{{"path":"dom/a.html","status":"OK","passed":2,"failed":1,"timed_out":0,"notrun":0,"_journal":"journal.shard1.jsonl","_mtime":{d}}},
        \\"dom/nodes/c.any.js":{{"path":"dom/nodes/c.any.js","status":"OK","passed":0,"failed":2,"timed_out":0,"notrun":0,"_journal":"journal.shard1.jsonl","_mtime":{d}}},
        \\"dom/b.html":{{"path":"dom/b.html","status":"TIMEOUT","passed":0,"failed":0,"timed_out":0,"notrun":0,"message":"took too long","_journal":"journal.shard1.jsonl","_mtime":{d}}},
        \\"url/u.html":{{"path":"url/u.html","status":"OK","passed":2,"failed":1,"timed_out":0,"notrun":0,"_journal":"journal.shard0.jsonl","_mtime":{d}}}}}
    , .{ m2, m2, m2, f.other_mtime });
    defer gpa.free(state2);
    var out = try f.tmp.dir.openDir(testing.io, "one", .{ .iterate = true });
    defer out.close(testing.io);
    const before_dom = try readOut(gpa, &f, "one/dom/index.html");
    defer gpa.free(before_dom);
    const before_nodes = try readOut(gpa, &f, "one/dom/nodes/index.html");
    defer gpa.free(before_nodes);
    const before_url = try readOut(gpa, &f, "one/url/index.html");
    defer gpa.free(before_url);
    const before_404 = try readOut(gpa, &f, "one/404.html");
    defer gpa.free(before_404);

    _ = try generate(gpa, testing.io, .{
        .state_json = state2,
        .history_json = fixture_history_next,
        .worklist_text = fixture_worklist,
        .results = f.results,
        .assets = null,
        .wpt = fixture_wpt,
    }, out);
    const index = try readOut(gpa, &f, "one/index.html");
    defer gpa.free(index);
    try expectHas(index, "Generation 3, recorded at Crane");
    try expectHas(index, "<code>sweep-def5678/journal.shard1</code> (3 files");
    // dom/ and dom/nodes/: same results, a new run - the same bytes.
    const after_dom = try readOut(gpa, &f, "one/dom/index.html");
    defer gpa.free(after_dom);
    try testing.expectEqualStrings(before_dom, after_dom);
    const after_nodes = try readOut(gpa, &f, "one/dom/nodes/index.html");
    defer gpa.free(after_nodes);
    try testing.expectEqualStrings(before_nodes, after_nodes);
    const after_404 = try readOut(gpa, &f, "one/404.html");
    defer gpa.free(after_404);
    try testing.expectEqualStrings(before_404, after_404);
    // url/: u.html's result moved, so its page did.
    const after_url = try readOut(gpa, &f, "one/url/index.html");
    defer gpa.free(after_url);
    try testing.expect(!std.mem.eql(u8, before_url, after_url));
}
