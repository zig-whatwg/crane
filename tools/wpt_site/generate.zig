//! Crane's public WPT results site: the generator.
//!
//!     zig build wpt-site [-- --out=<dir> --no-commit ...]
//!
//! Reads the progress report's accumulated state and history, the worklist,
//! and any per-subtest wptreport streams, and writes a static site (the
//! hand-written assets in tools/wpt_site/assets/ plus sharded JSON) to
//! --out. See tools/wpt_site/DESIGN.md for the pages and model.zig for the
//! rules.

const std = @import("std");
const model = @import("model.zig");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = std.Io.Dir;

test {
    _ = model;
}

pub const Revision = struct {
    sha: []const u8 = "",
    /// "upstream": the upstream WPT commit the fork's snapshot is based on
    /// (tests/wpt/.crane-upstream-revision); "fork": the fork's own commit,
    /// when no upstream revision is recorded; "unknown": neither.
    kind: []const u8 = "unknown",
};

pub const Inputs = struct {
    state_json: []const u8,
    history_json: []const u8,
    worklist_text: []const u8,
    worklist_name: []const u8 = "tests/wpt_0_1_worklist.txt",
    /// wpt-results/: journals (to locate each record's run) and streams.
    results: Dir,
    /// tools/wpt_site/assets/, copied verbatim; null writes data only.
    assets: ?Dir,
    wpt: Revision = .{},
};

pub const Summary = struct {
    files: usize = 0,
    detail_files: usize = 0,
    written: usize = 0,
    unchanged: usize = 0,
    removed: usize = 0,
    bytes: u64 = 0,
    generation: u64 = 0,
    head_buf: [40]u8 = undefined,
    head_len: usize = 0,

    /// The Crane commit the latest generation was recorded at.
    pub fn head(s: *const Summary) []const u8 {
        return s.head_buf[0..s.head_len];
    }
};

// ============================================================================
// Inputs
// ============================================================================

/// One record of tmp/wpt-progress-state.json: the latest journal line for a
/// test file, plus where it came from (`_journal`, `_mtime`: the journal's
/// basename and mtime, which tools/wpt_progress.py adds).
const Record = struct {
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

/// One generation of wpt-results/progress-history.json.
const Generation = struct {
    n: u64 = 0,
    at: []const u8 = "",
    head: []const u8 = "?",
    reconstructed: bool = false,
    gate_rule: ?u64 = null,
    total: u64 = 0,
    run: u64 = 0,
    unrun: u64 = 0,
    blocking: u64 = 0,
    crash: u64 = 0,
    timeout: u64 = 0,
    @"error": u64 = 0,
    none_passed: ?u64 = null,
    clean: u64 = 0,
    partial: u64 = 0,
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
fn listJournals(arena: Allocator, io: Io, results: Dir) ![]Journal {
    var out: std.ArrayList(Journal) = .empty;
    try scanJournals(arena, io, results, "", &out);
    var it = results.iterate();
    while (try it.next(io)) |e| {
        if (e.kind != .directory) continue;
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

const Run = struct {
    id: []const u8,
    commit: ?[]const u8,
    date: []const u8,
    journal: []const u8,
    files: u64 = 0,
};

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

fn writeMessage(w: *Io.Writer, msg: []const u8) !void {
    if (msg.len <= max_message) return std.json.Stringify.encodeJsonString(msg, .{}, w);
    var end: usize = max_message;
    while (end > 0 and (msg[end] & 0xC0) == 0x80) end -= 1;
    const cut = try std.fmt.allocPrint(std.heap.page_allocator, "{s} [message truncated at {d} bytes]", .{ msg[0..end], max_message });
    defer std.heap.page_allocator.free(cut);
    try std.json.Stringify.encodeJsonString(cut, .{}, w);
}

fn strField(o: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = o.get(key) orelse return null;
    return if (v == .string) v.string else null;
}

/// data/files/<source>.json: every run of the file, its subtests in the
/// harness's order. Past `model.detail_limit` subtests the passing ones are
/// counted, not listed.
fn writeDetail(gpa: Allocator, w: *Io.Writer, path: []const u8, lines: []const Line) !void {
    var scratch: std.heap.ArenaAllocator = .init(gpa);
    defer scratch.deinit();
    const a = scratch.allocator();
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

    try w.writeAll("{\"detail_limit\":");
    try w.print("{d},\"path\":", .{model.detail_limit});
    try std.json.Stringify.encodeJsonString(path, .{}, w);
    try w.writeAll(",\"runs\":[");
    for (parsed, lines, 0..) |o, l, i| {
        if (i > 0) try w.writeByte(',');
        const subs: []const std.json.Value = if (o.get("subtests")) |s| (if (s == .array) s.array.items else &.{}) else &.{};
        var c: struct { pass: u64 = 0, fail: u64 = 0, timeout: u64 = 0, notrun: u64 = 0, precondition_failed: u64 = 0 } = .{};
        for (subs) |sub| {
            if (sub != .object) continue;
            const st = strField(sub.object, "status") orelse "";
            if (std.mem.eql(u8, st, "PASS")) c.pass += 1 else if (std.mem.eql(u8, st, "FAIL")) c.fail += 1 else if (std.mem.eql(u8, st, "TIMEOUT")) c.timeout += 1 else if (std.mem.eql(u8, st, "NOTRUN")) c.notrun += 1 else c.precondition_failed += 1;
        }
        try w.print("{{\"counts\":{{\"fail\":{d},\"notrun\":{d},\"other\":{d},\"pass\":{d},\"timeout\":{d},\"total\":{d}}}", .{ c.fail, c.notrun, c.precondition_failed, c.pass, c.timeout, subs.len });
        if (strField(o, "message")) |m| {
            try w.writeAll(",\"message\":");
            try writeMessage(w, m);
        }
        try w.print(",\"passing_omitted\":{d},\"status\":", .{if (keep_passing) 0 else c.pass});
        try std.json.Stringify.encodeJsonString(strField(o, "status") orelse "ERROR", .{}, w);
        try w.writeAll(",\"subtests\":[");
        var first = true;
        for (subs) |sub| {
            if (sub != .object) continue;
            const st = strField(sub.object, "status") orelse "";
            if (!keep_passing and std.mem.eql(u8, st, "PASS")) continue;
            if (!first) try w.writeByte(',');
            first = false;
            try w.writeByte('{');
            if (strField(sub.object, "message")) |m| {
                try w.writeAll("\"message\":");
                try writeMessage(w, m);
                try w.writeByte(',');
            }
            try w.writeAll("\"name\":");
            try std.json.Stringify.encodeJsonString(strField(sub.object, "name") orelse "", .{}, w);
            try w.writeAll(",\"status\":");
            try std.json.Stringify.encodeJsonString(st, .{}, w);
            try w.writeByte('}');
        }
        try w.writeAll("],\"test\":");
        try std.json.Stringify.encodeJsonString(l.url, .{}, w);
        try w.writeByte('}');
    }
    try w.writeAll("]}\n");
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
        o.summary.bytes += bytes.len;
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

const FileEntry = struct {
    path: []const u8,
    rec: ?Record,
    gate: model.Gate,
    run: ?[]const u8,
    detail: bool,
};

const DirNode = struct {
    totals: model.Totals = .{},
    dirs: std.ArrayList([]const u8) = .empty,
    files: std.ArrayList(usize) = .empty,
};

/// "dom/nodes/x.html" -> "dom/nodes/"; "dom/x.html" -> "dom/".
fn parentDir(path: []const u8) []const u8 {
    const trimmed = if (std.mem.endsWith(u8, path, "/")) path[0 .. path.len - 1] else path;
    const i = std.mem.lastIndexOfScalar(u8, trimmed, '/') orelse return "";
    return path[0 .. i + 1];
}

fn baseName(path: []const u8) []const u8 {
    const trimmed = if (std.mem.endsWith(u8, path, "/")) path[0 .. path.len - 1] else path;
    const i = std.mem.lastIndexOfScalar(u8, trimmed, '/') orelse return trimmed;
    return trimmed[i + 1 ..];
}

/// data/dirs/dom.json for "dom/", data/dirs/dom/nodes.json for "dom/nodes/".
fn dirShard(arena: Allocator, dir: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "data/dirs/{s}.json", .{dir[0 .. dir.len - 1]});
}

fn writeFileEntry(w: *Io.Writer, f: FileEntry) !void {
    const c: model.Counts = if (f.rec) |r| r.counts() else .{};
    try w.print("{{\"counts\":{{\"fail\":{d},\"notrun\":{d},\"pass\":{d},\"timeout\":{d}}},\"detail\":{s},\"gate\":\"{s}\"", .{
        c.failed, c.notrun, c.passed, c.timed_out, if (f.detail) "true" else "false", f.gate.word(),
    });
    if (f.rec) |r| if (r.message) |m| {
        try w.writeAll(",\"message\":");
        try writeMessage(w, m);
    };
    try w.writeAll(",\"name\":");
    try std.json.Stringify.encodeJsonString(baseName(f.path), .{}, w);
    try w.writeAll(",\"path\":");
    try std.json.Stringify.encodeJsonString(f.path, .{}, w);
    try w.writeAll(",\"run\":");
    if (f.run) |r| try std.json.Stringify.encodeJsonString(r, .{}, w) else try w.writeAll("null");
    try w.writeAll(",\"status\":");
    if (f.rec) |r| try std.json.Stringify.encodeJsonString(r.status, .{}, w) else try w.writeAll("null");
    try w.writeByte('}');
}

fn writeOptU(w: *Io.Writer, v: ?u64) !void {
    if (v) |x| try w.print("{d}", .{x}) else try w.writeAll("null");
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
    const history = try std.json.parseFromSliceLeaky(History, arena, in.history_json, parse_options);
    const worklist = try parseWorklist(arena, in.worklist_text);
    const journals = try listJournals(arena, io, in.results);

    var known: std.StringHashMapUnmanaged(void) = .empty;
    for (worklist) |p| try known.put(arena, p, {});

    // Each in-scope record's run.
    var files = try arena.alloc(FileEntry, worklist.len);
    var used = try arena.alloc(bool, journals.len);
    @memset(used, false);
    var rec_journal: std.StringHashMapUnmanaged(usize) = .empty;
    var runs: std.StringArrayHashMapUnmanaged(Run) = .empty;
    for (worklist, 0..) |p, i| {
        const rec = state.map.get(p);
        files[i] = .{ .path = p, .rec = rec, .gate = model.gateOf(if (rec) |r| r.status else null, if (rec) |r| r.counts() else .{}), .run = null, .detail = false };
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

    var o: Output = .{ .gpa = gpa, .io = io, .dir = out, .arena = arena, .summary = &summary };
    if (in.assets) |a| try copyAssets(&o, a);
    try o.put(".nojekyll", "");

    // Per-subtest detail shards.
    var streams = try collectStreams(arena, io, in.results, journals, used, &known, &rec_journal);
    for (files) |*f| {
        const lines = streams.getPtr(f.path) orelse continue;
        if (lines.items.len == 0) continue;
        var aw: Io.Writer.Allocating = .init(gpa);
        defer aw.deinit();
        try writeDetail(gpa, &aw.writer, f.path, lines.items);
        const rel = try std.fmt.allocPrint(arena, "data/files/{s}.json", .{f.path});
        try o.put(rel, aw.written());
        f.detail = true;
        summary.detail_files += 1;
    }

    // Directory shards: every ancestor directory of every file.
    var nodes: std.StringArrayHashMapUnmanaged(DirNode) = .empty;
    try nodes.put(arena, "", .{});
    for (files, 0..) |f, i| {
        var child: []const u8 = f.path;
        var dir = parentDir(f.path);
        var is_file = true;
        while (true) {
            const gop = try nodes.getOrPut(arena, dir);
            const fresh = !gop.found_existing;
            if (fresh) gop.value_ptr.* = .{};
            gop.value_ptr.totals.add(f.gate, if (f.rec) |r| r.counts() else .{});
            if (is_file) try gop.value_ptr.files.append(arena, i);
            if (!is_file) {
                const list = &gop.value_ptr.dirs;
                if (list.items.len == 0 or !std.mem.eql(u8, list.items[list.items.len - 1], child)) {
                    var seen = false;
                    for (list.items) |d| if (std.mem.eql(u8, d, child)) {
                        seen = true;
                        break;
                    };
                    if (!seen) try list.append(arena, child);
                }
            }
            if (dir.len == 0) break;
            child = dir;
            dir = parentDir(dir);
            is_file = false;
        }
    }
    const dir_keys = try arena.dupe([]const u8, nodes.keys());
    std.mem.sort([]const u8, dir_keys, {}, lessStr);
    for (dir_keys) |dk| {
        const node = nodes.getPtr(dk).?;
        std.mem.sort([]const u8, node.dirs.items, {}, lessStr);
        if (dk.len == 0) continue;
        var aw: Io.Writer.Allocating = .init(gpa);
        defer aw.deinit();
        const w = &aw.writer;
        try w.writeAll("{\"dirs\":[");
        for (node.dirs.items, 0..) |d, i| {
            if (i > 0) try w.writeByte(',');
            const sub = nodes.getPtr(d).?;
            try w.print("{{\"dirs\":{d},\"files_here\":{d},\"name\":", .{ sub.dirs.items.len, sub.files.items.len });
            try std.json.Stringify.encodeJsonString(baseName(d), .{}, w);
            try w.writeAll(",\"path\":");
            try std.json.Stringify.encodeJsonString(d, .{}, w);
            try w.writeAll(",\"totals\":");
            try sub.totals.writeJson(w);
            try w.writeByte('}');
        }
        try w.writeAll("],\"files\":[");
        // files are appended in worklist (sorted) order already.
        for (node.files.items, 0..) |fi, i| {
            if (i > 0) try w.writeByte(',');
            try writeFileEntry(w, files[fi]);
        }
        try w.writeAll("],\"path\":");
        try std.json.Stringify.encodeJsonString(dk, .{}, w);
        try w.writeAll(",\"totals\":");
        try node.totals.writeJson(w);
        try w.writeAll("}\n");
        try o.put(try dirShard(arena, dk), aw.written());
    }

    // The suites: the root's children.
    const root = nodes.getPtr("").?;
    {
        var aw: Io.Writer.Allocating = .init(gpa);
        defer aw.deinit();
        const w = &aw.writer;
        try w.writeAll("{\"suites\":[");
        for (root.dirs.items, 0..) |d, i| {
            if (i > 0) try w.writeByte(',');
            const sub = nodes.getPtr(d).?;
            try w.print("{{\"dirs\":{d},\"files_here\":{d},\"name\":", .{ sub.dirs.items.len, sub.files.items.len });
            try std.json.Stringify.encodeJsonString(baseName(d), .{}, w);
            try w.writeAll(",\"path\":");
            try std.json.Stringify.encodeJsonString(d, .{}, w);
            try w.writeAll(",\"totals\":");
            try sub.totals.writeJson(w);
            try w.writeByte('}');
        }
        try w.writeAll("],\"totals\":");
        try root.totals.writeJson(w);
        try w.writeAll("}\n");
        try o.put("data/suites.json", aw.written());
    }

    // meta.json: the one file with timestamps - run identity and history.
    const gens = history.generations;
    const last: Generation = if (gens.len > 0) gens[gens.len - 1] else .{};
    {
        var aw: Io.Writer.Allocating = .init(gpa);
        defer aw.deinit();
        const w = &aw.writer;
        try w.writeAll("{\"generation\":{\"at\":");
        try std.json.Stringify.encodeJsonString(last.at, .{}, w);
        try w.writeAll(",\"gate_rule\":");
        try writeOptU(w, last.gate_rule);
        try w.writeAll(",\"head\":");
        try std.json.Stringify.encodeJsonString(last.head, .{}, w);
        try w.print(",\"n\":{d}}},\"history\":[", .{last.n});
        for (gens, 0..) |g, i| {
            if (i > 0) try w.writeByte(',');
            try w.writeAll("{\"at\":");
            try std.json.Stringify.encodeJsonString(g.at, .{}, w);
            try w.print(",\"blocking\":{d},\"clean\":{d},\"crash\":{d},\"error\":{d},\"gate_rule\":", .{ g.blocking, g.clean, g.crash, g.@"error" });
            try writeOptU(w, g.gate_rule);
            try w.writeAll(",\"head\":");
            try std.json.Stringify.encodeJsonString(g.head, .{}, w);
            try w.print(",\"n\":{d},\"none_passed\":", .{g.n});
            try writeOptU(w, g.none_passed);
            try w.print(",\"partial\":{d},\"reconstructed\":{s},\"run\":{d},\"timeout\":{d},\"total\":{d},\"unrun\":{d}}}", .{
                g.partial, if (g.reconstructed) "true" else "false", g.run, g.timeout, g.total, g.unrun,
            });
        }
        try w.writeAll("],\"links\":{\"crane\":\"https://github.com/zig-whatwg/crane\",\"wpt_fork\":\"https://github.com/zig-whatwg/wpt\",\"wpt_upstream\":\"https://github.com/web-platform-tests/wpt\"},\"runs\":{");
        const run_keys = try arena.dupe([]const u8, runs.keys());
        std.mem.sort([]const u8, run_keys, {}, lessStr);
        for (run_keys, 0..) |k, i| {
            if (i > 0) try w.writeByte(',');
            const r = runs.get(k).?;
            try std.json.Stringify.encodeJsonString(k, .{}, w);
            try w.writeAll(":{\"commit\":");
            if (r.commit) |c| try std.json.Stringify.encodeJsonString(c, .{}, w) else try w.writeAll("null");
            try w.writeAll(",\"date\":");
            try std.json.Stringify.encodeJsonString(r.date, .{}, w);
            try w.print(",\"files\":{d},\"journal\":", .{r.files});
            try std.json.Stringify.encodeJsonString(r.journal, .{}, w);
            try w.writeByte('}');
        }
        try w.print("}},\"scope\":{{\"detail_files\":{d},\"detail_limit\":{d},\"files\":{d},\"worklist\":", .{ summary.detail_files, model.detail_limit, worklist.len });
        try std.json.Stringify.encodeJsonString(in.worklist_name, .{}, w);
        try w.writeAll("},\"wpt\":{\"kind\":");
        try std.json.Stringify.encodeJsonString(in.wpt.kind, .{}, w);
        try w.writeAll(",\"revision\":");
        try std.json.Stringify.encodeJsonString(in.wpt.sha, .{}, w);
        try w.writeAll("}}\n");
        try o.put("data/meta.json", aw.written());
    }

    try o.prune();
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
        \\                [--assets=<dir>] [--out=<dir>] [--wpt-root=<dir>] [--no-commit]
        \\
        \\Defaults are the repository's: tmp/wpt-progress-state.json, wpt-results/progress-history.json,
        \\tests/wpt_0_1_worklist.txt, wpt-results/, tools/wpt_site/assets/, wpt-results/site/, tests/wpt/.
        \\When --out is a git worktree on the gh-pages branch and anything changed, the output is committed
        \\there ("results: generation <n>, Crane <sha>"). Nothing is ever pushed.
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
    var commit = true;

    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |a| {
        const eq = std.mem.indexOfScalar(u8, a, '=');
        const key = a[0 .. eq orelse a.len];
        const val = if (eq) |i| a[i + 1 ..] else "";
        if (std.mem.eql(u8, key, "--no-commit")) commit = false else if (eq == null) usage() else if (std.mem.eql(u8, key, "--state")) state_path = val else if (std.mem.eql(u8, key, "--history")) history_path = val else if (std.mem.eql(u8, key, "--worklist")) worklist_path = val else if (std.mem.eql(u8, key, "--results")) results_path = val else if (std.mem.eql(u8, key, "--assets")) assets_path = val else if (std.mem.eql(u8, key, "--out")) out_path = val else if (std.mem.eql(u8, key, "--wpt-root")) wpt_root = val else usage();
    }

    const cwd = Dir.cwd();
    const state = try cwd.readFileAlloc(io, state_path, arena, .limited(1 << 31));
    const history = try cwd.readFileAlloc(io, history_path, arena, .limited(1 << 31));
    const worklist = try cwd.readFileAlloc(io, worklist_path, arena, .limited(1 << 28));
    var results = try cwd.openDir(io, results_path, .{ .iterate = true });
    defer results.close(io);
    var assets = try cwd.openDir(io, assets_path, .{ .iterate = true });
    defer assets.close(io);
    var out = try cwd.createDirPathOpen(io, out_path, .{ .open_options = .{ .iterate = true } });
    defer out.close(io);

    const summary = try generate(init.gpa, io, .{
        .state_json = state,
        .history_json = history,
        .worklist_text = worklist,
        .worklist_name = worklist_path,
        .results = results,
        .assets = assets,
        .wpt = detectRevision(arena, io, wpt_root),
    }, out);
    std.debug.print(
        "wpt-site: generation {d} (Crane {s}): {d} files, {d} with subtest detail; {d} written, {d} unchanged, {d} removed; {d} bytes in {s}\n",
        .{ summary.generation, summary.head(), summary.files, summary.detail_files, summary.written, summary.unchanged, summary.removed, summary.bytes, out_path },
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
    \\{"n":1,"at":"2026-09-19T19:55:00","head":"?","reconstructed":true,"total":5,"run":2,"unrun":3,"blocking":1,"crash":0,"timeout":1,"error":0,"clean":1,"partial":0,"sub_pass":3,"sub_fail":0},
    \\{"n":2,"at":"2026-09-30T11:21:23","head":"5c8dd64da","gate_rule":2,"total":5,"run":4,"unrun":1,"blocking":2,"crash":0,"timeout":1,"error":0,"none_passed":1,"clean":1,"partial":1,"sub_pass":5,"sub_fail":3}
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
    \\{"test":"/dom/a.html","status":"OK","message":null,"duration":5,"subtests":[{"name":"one","status":"PASS","message":null},{"name":"two","status":"FAIL","message":"assert_equals: expected 1 but got 2"},{"name":"three","status":"PASS","message":null}]}
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
        .wpt = .{ .sha = "50d8c16fa8219824aad90ef0ec02328e7ecbc8e5", .kind = "fork" },
    }, out);
}

fn readOut(gpa: Allocator, f: *Fixture, path: []const u8) ![]u8 {
    return f.tmp.dir.readFileAlloc(testing.io, path, gpa, .limited(1 << 24));
}

test "site: directory shards roll totals up, sorted, with NONE-PASSED blocking" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    try testing.expectEqual(@as(usize, 5), s.files);
    try testing.expectEqual(@as(u64, 2), s.generation);

    const dom = try readOut(gpa, &f, "out/data/dirs/dom.json");
    defer gpa.free(dom);
    const parsed = try std.json.parseFromSlice(std.json.Value, gpa, dom, .{});
    defer parsed.deinit();
    const o = parsed.value.object;
    try testing.expectEqualStrings("dom/", o.get("path").?.string);
    const t = o.get("totals").?.object;
    try testing.expectEqual(@as(i64, 3), t.get("files").?.integer);
    // b.html TIMEOUT + c.any.js OK-with-nothing-passing.
    try testing.expectEqual(@as(i64, 2), t.get("blocking").?.integer);
    try testing.expectEqual(@as(i64, 1), t.get("none_passed").?.integer);
    try testing.expectEqual(@as(i64, 1), t.get("partial").?.integer);
    // Files sorted by name: a.html before b.html.
    const files = o.get("files").?.array.items;
    try testing.expectEqual(@as(usize, 2), files.len);
    try testing.expectEqualStrings("a.html", files[0].object.get("name").?.string);
    try testing.expectEqualStrings("b.html", files[1].object.get("name").?.string);
    try testing.expectEqualStrings("timeout", files[1].object.get("gate").?.string);
    try testing.expectEqualStrings("took too long", files[1].object.get("message").?.string);
    try testing.expectEqualStrings("sweep-abc1234", files[1].object.get("run").?.string);
    const dirs = o.get("dirs").?.array.items;
    try testing.expectEqual(@as(usize, 1), dirs.len);
    try testing.expectEqualStrings("dom/nodes/", dirs[0].object.get("path").?.string);

    // The suite index names both suites, in order, and the unrun file counts.
    const suites = try readOut(gpa, &f, "out/data/suites.json");
    defer gpa.free(suites);
    const sp = try std.json.parseFromSlice(std.json.Value, gpa, suites, .{});
    defer sp.deinit();
    const list = sp.value.object.get("suites").?.array.items;
    try testing.expectEqual(@as(usize, 2), list.len);
    try testing.expectEqualStrings("dom", list[0].object.get("name").?.string);
    try testing.expectEqualStrings("url", list[1].object.get("name").?.string);
    try testing.expectEqual(@as(i64, 1), list[1].object.get("totals").?.object.get("unrun").?.integer);
}

test "site: per-subtest detail comes only from the record's own run's stream" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    const s = try runFixture(gpa, &f, "out", fixture_worklist);
    // a.html and c.any.js have detail; b.html's only stream line is in a
    // stream from another run, which must not be used.
    try testing.expectEqual(@as(usize, 2), s.detail_files);

    const a = try readOut(gpa, &f, "out/data/files/dom/a.html.json");
    defer gpa.free(a);
    try testing.expect(std.mem.indexOf(u8, a, "assert_equals: expected 1 but got 2") != null);
    try testing.expect(std.mem.indexOf(u8, a, "\"one\"") != null);

    // Two runs of c.any.js, sorted by test URL.
    const c = try readOut(gpa, &f, "out/data/files/dom/nodes/c.any.js.json");
    defer gpa.free(c);
    const i_win = std.mem.indexOf(u8, c, "/dom/nodes/c.any.html").?;
    const i_wkr = std.mem.indexOf(u8, c, "/dom/nodes/c.any.worker.html").?;
    try testing.expect(i_win < i_wkr);

    try testing.expectError(error.FileNotFound, f.tmp.dir.statFile(testing.io, "out/data/files/dom/b.html.json", .{}));
    const dom = try readOut(gpa, &f, "out/data/dirs/dom.json");
    defer gpa.free(dom);
    try testing.expect(std.mem.indexOf(u8, dom, "\"detail\":true") != null);
    try testing.expect(std.mem.indexOf(u8, dom, "\"detail\":false") != null);
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

    const a = try readOut(gpa, &f, "out/data/files/dom/a.html.json");
    defer gpa.free(a);
    const p = try std.json.parseFromSlice(std.json.Value, gpa, a, .{});
    defer p.deinit();
    const run = p.value.object.get("runs").?.array.items[0].object;
    try testing.expectEqual(@as(i64, 504), run.get("passing_omitted").?.integer);
    const subs = run.get("subtests").?.array.items;
    try testing.expectEqual(@as(usize, 6), subs.len);
    for (subs) |sub| try testing.expectEqualStrings("FAIL", sub.object.get("status").?.string);
    try testing.expectEqual(@as(i64, 510), run.get("counts").?.object.get("total").?.integer);
}

test "site: an unchanged input writes byte-identical files, and only meta.json carries timestamps" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "one", fixture_worklist);
    const again = try runFixture(gpa, &f, "one", fixture_worklist);
    try testing.expectEqual(@as(usize, 0), again.written);
    _ = try runFixture(gpa, &f, "two", fixture_worklist);

    var one = try f.tmp.dir.openDir(testing.io, "one", .{ .iterate = true });
    defer one.close(testing.io);
    var walker = try one.walk(gpa);
    defer walker.deinit();
    var n: usize = 0;
    while (try walker.next(testing.io)) |e| {
        if (e.kind != .file) continue;
        n += 1;
        const a = try one.readFileAlloc(testing.io, e.path, gpa, .limited(1 << 24));
        defer gpa.free(a);
        const other = try std.fmt.allocPrint(gpa, "two/{s}", .{e.path});
        defer gpa.free(other);
        const b = try readOut(gpa, &f, other);
        defer gpa.free(b);
        try testing.expectEqualStrings(a, b);
        if (!std.mem.eql(u8, e.path, "data/meta.json")) {
            try testing.expect(std.mem.indexOf(u8, a, "2026-") == null);
        }
    }
    try testing.expect(n >= 6);
    const meta = try readOut(gpa, &f, "one/data/meta.json");
    defer gpa.free(meta);
    try testing.expect(std.mem.indexOf(u8, meta, "\"sweep-abc1234\"") != null);
    try testing.expect(std.mem.indexOf(u8, meta, "\"commit\":\"abc1234\"") != null);
    try testing.expect(std.mem.indexOf(u8, meta, "50d8c16fa8219824aad90ef0ec02328e7ecbc8e5") != null);
}

test "site: a file that leaves the worklist loses its shards; .git is never touched" {
    const gpa = testing.allocator;
    var f = try Fixture.init(fixture_stream);
    defer f.deinit();
    _ = try runFixture(gpa, &f, "out", fixture_worklist);
    try f.tmp.dir.writeFile(testing.io, .{ .sub_path = "out/.git", .data = "gitdir: elsewhere\n" });
    const smaller =
        \\dom/b.html
        \\url/u.html
        \\
    ;
    const s = try runFixture(gpa, &f, "out", smaller);
    try testing.expect(s.removed >= 2);
    try testing.expectError(error.FileNotFound, f.tmp.dir.statFile(testing.io, "out/data/files/dom/a.html.json", .{}));
    try testing.expectError(error.FileNotFound, f.tmp.dir.statFile(testing.io, "out/data/dirs/dom/nodes.json", .{}));
    _ = try f.tmp.dir.statFile(testing.io, "out/.git", .{});
    _ = try f.tmp.dir.statFile(testing.io, "out/.nojekyll", .{});
}

test "assets: index.html opens its body with the direction contract, verbatim" {
    const html = @embedFile("assets/index.html");
    const body = std.mem.indexOf(u8, html, "<body") orelse return error.NoBody;
    const after = std.mem.indexOfScalarPos(u8, html, body, '>').? + 1;
    const rest = std.mem.trimStart(u8, html[after..], " \t\r\n");
    try testing.expect(std.mem.startsWith(u8, rest, "<!--\nTHESIS: "));
    try testing.expect(std.mem.indexOf(u8, rest, "seed a0daf20c") != null);
    try testing.expect(std.mem.indexOf(u8, rest, "FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md\n-->") != null);
}
