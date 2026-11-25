//! `wpt_ab`: a lane's WPT A/B, run the way .claude/rules/wpt-workflow.md
//! says, in one committed tool (lane tool1-ab, 2026-11-25). It replaces the
//! A/B scripts the lanes copied from each other (mem1's wptab.sh -> maj1 ->
//! cs1 -> core1 -> bind1's ab.sh; hard1's abfull.sh), whose faults it exists
//! to refuse:
//!
//! - a runner given no file runs EVERY test of the tree: hard1-usp's
//!   targeted url/ A/B took its timer files from the targeted list, got
//!   none, and ran the whole tree as "timers" for 70 minutes on server1
//!   (2026-11-25). Every step here refuses an empty file list, and the
//!   timer files come from the WHOLE worklist - a worklist without one
//!   skips the step with a line, never "all";
//! - pass counts come from the journals' records (a file's status and its
//!   passed subtests), never from grepping a log;
//! - each side's journal is counted against the list before any verdict: a
//!   record for every listed file, none twice, none unlisted;
//! - the compare blocks each lane re-typed in Python are this file, on
//!   build_compare.zig's readers of the journal and the result streams.
//!
//!   wpt_ab --tip=<frozen dir> --tip-commit=<sha>
//!          (--base=<frozen dir> --base-commit=<sha> | --base-generation=<frozen generation dir>)
//!          --out=<dir> [--out-exists=refuse|move-aside]
//!          (--dirs=<prefix,...> | --full) [--extra-dirs=<prefix,...>] [--files=<list file>]
//!          [--crane-tests=<path,...>]
//!          [--steps=ab,bug,rerun,timers,verify[,verifybase]] [--runners=16] [--reruns=3]
//!          [--timers=3] [--verify-repeat=10] [--wpt-root=<dir>] [--measure=<crane-measure.sh>]
//!          [--label=<lane>] [--stop-file=<f> ...] [--dry-run]
//!
//! A frozen dir holds the runners of one tree: wpt_runner,
//! wpt_runner_bug_finding, wpt_build_compare and whatwg_snapshot.bin with a
//! SHA256SUMS over them (in <dir>/zig-out/bin or in <dir> itself), and
//! worklist.txt, wpt_build_differences.txt and BUILD_INFO (naming its
//! commit) in <dir>. A frozen generation (~/crane-frozen/main-<sha>) is a
//! frozen dir with its full run's journal and result streams in full/: as
//! the base, only the tip runs, and the base is that run, read for the
//! listed files.
//!
//! Exit: 0 no loss and every gate held; 1 a finding (a file that lost
//! subtests, a new blocking file or crash, the bug-finding gate, a verify
//! that is not stable) - the report names each, the ruling is the
//! integrator's; 2 an input check; 3 a STOP file; 4 a run is incomplete
//! (its records are not the list: no verdict).

const std = @import("std");
const host = @import("host");
const common = @import("window_common");
const journal = @import("journal.zig");
const build_compare = @import("build_compare.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Exit = enum(u8) {
    clean = 0,
    findings = 1,
    input = 2,
    stopped = 3,
    incomplete = 4,
};

pub const Step = enum { ab, bug, rerun, timers, verify, verifybase };

pub fn parseSteps(arena: Allocator, text: []const u8) error{ OutOfMemory, UnknownStep, NoSteps }![]const Step {
    var out: std.ArrayList(Step) = .empty;
    var it = std.mem.tokenizeAny(u8, text, ", ");
    while (it.next()) |name| try out.append(arena, std.meta.stringToEnum(Step, name) orelse return error.UnknownStep);
    if (out.items.len == 0) return error.NoSteps;
    return out.items;
}

pub const Options = struct {
    tip: []const u8,
    tip_commit: []const u8,
    base: ?[]const u8 = null,
    base_commit: ?[]const u8 = null,
    base_generation: ?[]const u8 = null,
    out: []const u8,
    move_aside: bool = false,
    dirs: []const []const u8 = &.{},
    full: bool = false,
    extra_dirs: []const []const u8 = &.{},
    files: ?[]const u8 = null,
    crane_tests: []const []const u8 = &.{},
    steps: []const Step = &.{ .ab, .bug, .rerun, .timers, .verify },
    runners: u32 = 16,
    reruns: u32 = 3,
    timers: u32 = 3,
    verify_repeat: u32 = 10,
    wpt_root: ?[]const u8 = null,
    measure: ?[]const u8 = null,
    label: []const u8 = "ab",
    stop_files: []const []const u8 = &.{},
    dry_run: bool = false,
};

// ---------------------------------------------------------------------------
// Lists.

/// The worklist's paths: every line that is not empty or a comment, trimmed.
pub fn worklistPaths(arena: Allocator, text: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        try out.append(arena, line);
    }
    return out.items;
}

/// Whether `path` is under the directory `prefix` ("url" and "url/" both
/// name url/; "url" does not take "urlpattern/").
pub fn under(path: []const u8, prefix: []const u8) bool {
    const p = std.mem.trimEnd(u8, std.mem.trimStart(u8, prefix, "/"), "/");
    if (p.len == 0) return false;
    return std.mem.startsWith(u8, path, p) and path.len > p.len and path[p.len] == '/';
}

/// The paths under any of `dirs`.
pub fn pathsUnder(arena: Allocator, paths: []const []const u8, dirs: []const []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (paths) |p| for (dirs) |d| if (under(p, d)) {
        try out.append(arena, p);
        break;
    };
    return out.items;
}

/// The timer files of the regression protocol (tests/AGENTS.md): the
/// WHOLE worklist's html/webappapis/timers/ files, whatever the A/B's own
/// list holds.
pub const timers_dir = "html/webappapis/timers";

pub fn timerFiles(arena: Allocator, worklist: []const []const u8) ![]const []const u8 {
    return pathsUnder(arena, worklist, &.{timers_dir});
}

/// `paths` sorted, each once.
pub fn sortUnique(arena: Allocator, paths: []const []const u8) ![]const []const u8 {
    const out = try arena.dupe([]const u8, paths);
    std.mem.sort([]const u8, out, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lt);
    var n: usize = 0;
    for (out) |p| {
        if (n > 0 and std.mem.eql(u8, out[n - 1], p)) continue;
        out[n] = p;
        n += 1;
    }
    return out[0..n];
}

/// Why a step may not run on `list`, or null. A runner given no file runs
/// every test of the tree (2026-11-25), so an empty list never reaches one.
pub fn emptyListProblem(arena: Allocator, step: []const u8, list: []const []const u8, what: []const u8) !?[]const u8 {
    if (list.len > 0) return null;
    return try std.fmt.allocPrint(arena, "{s}: the file list is empty ({s}) - a runner given no file runs the whole tree; not run", .{ step, what });
}

/// The source file a result stream's test URL comes from: the journal's
/// path, with a generated test named by the file it is generated from
/// (`url/a.any.worker.html` -> `url/a.any.js`; `.window.html`,
/// `.worker.html` likewise).
pub fn sourceOf(arena: Allocator, test_id: []const u8) ![]const u8 {
    const path = build_compare.journalPathOf(test_id);
    const generated = [_]struct { []const u8, []const u8 }{
        .{ ".any.sharedworker.html", ".any.js" },
        .{ ".any.serviceworker.html", ".any.js" },
        .{ ".any.worker.html", ".any.js" },
        .{ ".any.shadowrealm.html", ".any.js" },
        .{ ".any.html", ".any.js" },
        .{ ".window.html", ".window.js" },
        .{ ".worker.html", ".worker.js" },
    };
    for (generated) |g| if (std.mem.endsWith(u8, path, g[0])) {
        return std.mem.concat(arena, u8, &.{ path[0 .. path.len - g[0].len], g[1] });
    };
    return path;
}

// ---------------------------------------------------------------------------
// Records: one side's journal against its list.

/// A file the 0.1 gate counts as blocking (tools/wpt_progress.py GATING):
/// not OK, or OK with none of its subtests passing - a file with no
/// subtests at all does not block (nothing failed).
pub fn blocks(r: journal.Record) bool {
    if (r.status != .ok) return true;
    return r.passed == 0 and r.failed + r.timed_out + r.notrun > 0;
}

/// One side's records of the listed files, counted.
pub const Side = struct {
    files: u32 = 0,
    ok: u32 = 0,
    @"error": u32 = 0,
    timeout: u32 = 0,
    crash: u32 = 0,
    blocking: u32 = 0,
    passed: u64 = 0,
    failed: u64 = 0,
};

/// A side's journal against its list: a record for every listed file, none
/// twice, none unlisted.
pub const RecordCount = struct {
    listed: u32 = 0,
    found: u32 = 0,
    missing: u32 = 0,
    duplicate: u32 = 0,
    unlisted: u32 = 0,
    first_missing: []const u8 = "",
    first_unlisted: []const u8 = "",

    pub fn complete(c: RecordCount) bool {
        return c.found == c.listed and c.missing == 0 and c.duplicate == 0 and c.unlisted == 0;
    }

    pub fn write(c: RecordCount, w: *Io.Writer) !void {
        try w.print("{d} of {d} listed files have a record", .{ c.found, c.listed });
        if (c.complete()) return;
        try w.writeAll(" - INCOMPLETE:");
        if (c.missing > 0) try w.print(" {d} missing (the first: {s})", .{ c.missing, c.first_missing });
        if (c.duplicate > 0) try w.print(" {d} recorded twice", .{c.duplicate});
        if (c.unlisted > 0) try w.print(" {d} not on the list (the first: {s}: another run's records?)", .{ c.unlisted, c.first_unlisted });
    }
};

/// `records` (one run's journal) against `list`: its count, and its side's
/// figures over the listed files. With `only_listed` (a frozen generation's
/// full run read as a base), records of other files are not this run's
/// fault and are passed over.
pub fn countSide(arena: Allocator, records: []const journal.Record, list: []const []const u8, only_listed: bool) !struct { count: RecordCount, side: Side } {
    var index: std.StringHashMapUnmanaged(u32) = .empty;
    for (list, 0..) |p, i| try index.put(arena, p, @intCast(i));
    const seen = try arena.alloc(u32, list.len);
    @memset(seen, 0);
    var c: RecordCount = .{ .listed = @intCast(list.len) };
    var s: Side = .{};
    for (records) |r| {
        const i = index.get(r.path) orelse {
            if (!only_listed) {
                if (c.unlisted == 0) c.first_unlisted = r.path;
                c.unlisted += 1;
            }
            continue;
        };
        seen[i] += 1;
        if (seen[i] > 1) {
            c.duplicate += 1;
            continue;
        }
        c.found += 1;
        s.files += 1;
        switch (r.status) {
            .ok => s.ok += 1,
            .@"error" => s.@"error" += 1,
            .timeout => s.timeout += 1,
            .crash => s.crash += 1,
        }
        if (blocks(r)) s.blocking += 1;
        s.passed += r.passed;
        s.failed += r.failed;
    }
    for (list, seen) |p, n| if (n == 0) {
        if (c.missing == 0) c.first_missing = p;
        c.missing += 1;
    };
    return .{ .count = c, .side = s };
}

// ---------------------------------------------------------------------------
// The comparison.

/// A listed file whose record differs between the sides.
pub const FileChange = struct {
    path: []const u8,
    base_status: []const u8,
    tip_status: []const u8,
    base_passed: usize,
    tip_passed: usize,
    base_blocks: bool,
    tip_blocks: bool,

    pub fn lost(f: FileChange) bool {
        return f.tip_passed < f.base_passed;
    }
    pub fn newlyBlocking(f: FileChange) bool {
        return f.tip_blocks and !f.base_blocks;
    }
    pub fn newCrash(f: FileChange) bool {
        return std.mem.eql(u8, f.tip_status, "CRASH") and !std.mem.eql(u8, f.base_status, "CRASH");
    }
};

/// The listed files whose status or passed count differs, in list order.
pub fn fileChanges(arena: Allocator, base: []const journal.Record, tip: []const journal.Record, list: []const []const u8) ![]const FileChange {
    var b: std.StringHashMapUnmanaged(journal.Record) = .empty;
    var t: std.StringHashMapUnmanaged(journal.Record) = .empty;
    for (base) |r| if (!b.contains(r.path)) try b.put(arena, r.path, r);
    for (tip) |r| if (!t.contains(r.path)) try t.put(arena, r.path, r);
    var out: std.ArrayList(FileChange) = .empty;
    for (list) |p| {
        const x = b.get(p);
        const y = t.get(p);
        const bs = if (x) |r| r.status.toString() else build_compare.missing;
        const ts = if (y) |r| r.status.toString() else build_compare.missing;
        const bp = if (x) |r| r.passed else 0;
        const tp = if (y) |r| r.passed else 0;
        if (std.mem.eql(u8, bs, ts) and bp == tp) continue;
        try out.append(arena, .{
            .path = p,
            .base_status = bs,
            .tip_status = ts,
            .base_passed = bp,
            .tip_passed = tp,
            .base_blocks = if (x) |r| blocks(r) else false,
            .tip_blocks = if (y) |r| blocks(r) else false,
        });
    }
    return out.items;
}

/// A subtest (or a test's own status, `subtest` empty) whose result differs.
pub const SubtestChange = struct {
    source: []const u8,
    test_id: []const u8,
    subtest: []const u8,
    base: []const u8,
    tip: []const u8,
};

/// Every test and subtest of a listed file whose result differs between the
/// two runs' result streams.
pub fn subtestChanges(arena: Allocator, base: *const build_compare.Run, tip: *const build_compare.Run, list: []const []const u8) ![]const SubtestChange {
    var listed: std.StringHashMapUnmanaged(void) = .empty;
    for (list) |p| try listed.put(arena, p, {});
    var ids: std.StringArrayHashMapUnmanaged(void) = .empty;
    for (base.tests.keys()) |k| try ids.put(arena, k, {});
    for (tip.tests.keys()) |k| try ids.put(arena, k, {});
    var out: std.ArrayList(SubtestChange) = .empty;
    for (ids.keys()) |id| {
        const source = try sourceOf(arena, id);
        if (!listed.contains(source)) continue;
        const x = base.tests.get(id);
        const y = tip.tests.get(id);
        const xs = if (x) |r| r.status else build_compare.missing;
        const ys = if (y) |r| r.status else build_compare.missing;
        if (!std.mem.eql(u8, xs, ys)) try out.append(arena, .{ .source = source, .test_id = id, .subtest = "", .base = xs, .tip = ys });
        var names: std.StringArrayHashMapUnmanaged(void) = .empty;
        if (x) |r| for (r.subtests.keys()) |n| try names.put(arena, n, {});
        if (y) |r| for (r.subtests.keys()) |n| try names.put(arena, n, {});
        for (names.keys()) |n| {
            const a = if (x) |r| r.subtests.get(n) orelse build_compare.missing else build_compare.missing;
            const b = if (y) |r| r.subtests.get(n) orelse build_compare.missing else build_compare.missing;
            if (!std.mem.eql(u8, a, b)) try out.append(arena, .{ .source = source, .test_id = id, .subtest = n, .base = a, .tip = b });
        }
    }
    return out.items;
}

/// The files the A/B changed, sorted: those whose record changed and those
/// with a test or subtest that changed.
pub fn changedFiles(arena: Allocator, files: []const FileChange, subtests: []const SubtestChange) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (files) |f| try out.append(arena, f.path);
    for (subtests) |s| try out.append(arena, s.source);
    return sortUnique(arena, out.items);
}

/// What the comparison finds, for the verdict.
pub const Findings = struct {
    lost_files: u32 = 0,
    newly_blocking: u32 = 0,
    new_crashes: u32 = 0,

    pub fn of(files: []const FileChange) Findings {
        var f: Findings = .{};
        for (files) |c| {
            if (c.lost()) f.lost_files += 1;
            if (c.newlyBlocking()) f.newly_blocking += 1;
            if (c.newCrash()) f.new_crashes += 1;
        }
        return f;
    }

    pub fn any(f: Findings) bool {
        return f.lost_files + f.newly_blocking + f.new_crashes > 0;
    }
};

/// The A/B's summary lines: each side's figures and the deltas.
pub fn writeSides(w: *Io.Writer, base: Side, tip: Side) !void {
    try w.print("  files: base {d} tip {d}; OK {d} -> {d}; ERROR {d} -> {d}; TIMEOUT {d} -> {d}; CRASH {d} -> {d}\n", .{ base.files, tip.files, base.ok, tip.ok, base.@"error", tip.@"error", base.timeout, tip.timeout, base.crash, tip.crash });
    const bp: i64 = @intCast(base.passed);
    const tp: i64 = @intCast(tip.passed);
    const bb: i64 = base.blocking;
    const tb: i64 = tip.blocking;
    try w.print("  passed subtests: base {d} tip {d} ({s}{d}); blocking files: base {d} tip {d} ({s}{d})\n", .{ base.passed, tip.passed, sign(tp - bp), tp - bp, base.blocking, tip.blocking, sign(tb - bb), tb - bb });
}

/// "+" before a delta that is not negative (a negative one prints its own).
fn sign(d: i64) []const u8 {
    return if (d >= 0) "+" else "";
}

// ---------------------------------------------------------------------------
// Frozen dirs.

/// What a frozen dir's SHA256SUMS must cover: the production runner and its
/// snapshot always; the bug-finding runner and wpt_build_compare when the
/// A/B runs its `bug` step.
pub const runner_files = [_][]const u8{ "wpt_runner", "whatwg_snapshot.bin" };
pub const bug_files = [_][]const u8{ "wpt_runner", "whatwg_snapshot.bin", "wpt_runner_bug_finding", "wpt_build_compare" };

pub const Frozen = struct {
    dir: []const u8,
    commit: []const u8,
    /// Where the runners and their SHA256SUMS are.
    bin: []const u8,
    runner: []const u8,
    bug_runner: []const u8,
    build_compare: []const u8,
    runner_sha256: [64]u8,
    worklist: []const u8,
    known: []const u8,
    build_info: []const u8,
};

pub fn Checked(comptime T: type) type {
    return union(enum) { ok: T, problem: []const u8 };
}

fn exists(io: Io, path: []const u8) bool {
    Io.Dir.cwd().access(io, path, .{}) catch return false;
    return true;
}

/// `dir` as a side of the A/B: its runners' SHA256SUMS hold (in
/// <dir>/zig-out/bin, or in <dir> for a flat freeze), its worklist and
/// known differences are there, and its BUILD_INFO names `commit` (a frozen
/// generation, which has none, is named by its directory: main-<sha>).
pub fn checkFrozen(arena: Allocator, io: Io, dir: []const u8, commit: []const u8, need_bug: bool) !Checked(Frozen) {
    const bad = struct {
        fn f(a: Allocator, comptime fmt: []const u8, args: anytype) !Checked(Frozen) {
            return .{ .problem = try std.fmt.allocPrint(a, fmt, args) };
        }
    }.f;
    if (!std.fs.path.isAbsolute(dir)) return bad(arena, "{s}: a frozen dir is named by its absolute path", .{dir});
    const nested = try std.fs.path.join(arena, &.{ dir, "zig-out", "bin" });
    const bin = if (exists(io, try std.fs.path.join(arena, &.{ nested, "SHA256SUMS" }))) nested else dir;
    if (try common.sumsProblem(arena, io, bin, if (need_bug) &bug_files else &runner_files)) |p| return bad(arena, "{s}", .{p});
    const worklist = try std.fs.path.join(arena, &.{ dir, "worklist.txt" });
    if (!exists(io, worklist)) return bad(arena, "{s} missing", .{worklist});
    const known = try std.fs.path.join(arena, &.{ dir, "wpt_build_differences.txt" });
    if (!exists(io, known)) return bad(arena, "{s} missing", .{known});
    const info_path = try std.fs.path.join(arena, &.{ dir, "BUILD_INFO" });
    const info = Io.Dir.cwd().readFileAlloc(io, info_path, arena, .limited(64 * 1024)) catch "";
    const named_by = if (info.len > 0) info else std.fs.path.basename(dir);
    if (!common.mentionsCommit(named_by, commit)) return bad(arena, "{s}: {s} does not name commit {s}", .{ dir, if (info.len > 0) "BUILD_INFO" else "its name (no BUILD_INFO)", commit });
    const runner = try std.fs.path.join(arena, &.{ bin, "wpt_runner" });
    var sha: [64]u8 = undefined;
    try common.sha256File(io, runner, &sha);
    return .{ .ok = .{
        .dir = dir,
        .commit = commit,
        .bin = bin,
        .runner = runner,
        .bug_runner = try std.fs.path.join(arena, &.{ bin, "wpt_runner_bug_finding" }),
        .build_compare = try std.fs.path.join(arena, &.{ bin, "wpt_build_compare" }),
        .runner_sha256 = sha,
        .worklist = worklist,
        .known = known,
        .build_info = std.mem.trim(u8, info, " \t\r\n"),
    } };
}

/// A frozen generation's commit: its directory's name, main-<sha>.
pub fn generationCommit(dir: []const u8) ?[]const u8 {
    const name = std.fs.path.basename(dir);
    const prefix = "main-";
    if (!std.mem.startsWith(u8, name, prefix)) return null;
    const sha = name[prefix.len..];
    if (sha.len < 7) return null;
    for (sha) |c| if (!common.isHex(c)) return null;
    return sha;
}

// ---------------------------------------------------------------------------
// The window.

const Window = struct {
    arena: Allocator,
    io: Io,
    opts: Options,
    measure: []const u8,
    wpt_root: []const u8,
    log: ?Io.File = null,
    findings: bool = false,

    fn nowS(w: *const Window) i64 {
        return @intCast(@divFloor(Io.Clock.real.now(w.io).nanoseconds, std.time.ns_per_s));
    }

    fn when(w: *const Window, date: bool) []const u8 {
        const buf = w.arena.alloc(u8, 48) catch return "?";
        return common.easternTime(buf, w.nowS(), date);
    }

    fn say(w: *Window, comptime fmt: []const u8, args: anytype) void {
        const text = std.fmt.allocPrint(w.arena, fmt ++ "\n", args) catch return;
        Io.File.stdout().writeStreamingAll(w.io, text) catch {};
        if (w.log) |f| f.writeStreamingAll(w.io, text) catch {};
    }

    fn stopFile(w: *const Window) ?[]const u8 {
        for (w.opts.stop_files) |f| if (exists(w.io, f)) return f;
        return null;
    }

    fn path(w: *const Window, name: []const u8) ![]const u8 {
        return std.fs.path.join(w.arena, &.{ w.opts.out, name });
    }

    fn writeList(w: *Window, name: []const u8, list: []const []const u8) ![]const u8 {
        var text: Io.Writer.Allocating = .init(w.arena);
        for (list) |p| try text.writer.print("{s}\n", .{p});
        const p = try w.path(name);
        try Io.Dir.cwd().writeFile(w.io, .{ .sub_path = p, .data = text.written() });
        return p;
    }

    /// Runs `argv` in the WPT tree, its output to `log_path`; its exit
    /// status (128 + n for signal n).
    fn child(w: *Window, argv: []const []const u8, log_path: []const u8) !u8 {
        var file = try Io.Dir.cwd().createFile(w.io, log_path, .{ .exclusive = true });
        defer file.close(w.io);
        var c = try std.process.spawn(w.io, .{
            .argv = argv,
            .cwd = .{ .path = w.wpt_root },
            .stdin = .ignore,
            .stdout = .{ .file = file },
            .stderr = .{ .file = file },
        });
        const term = try c.wait(w.io);
        return switch (term) {
            .exited => |code| code,
            .signal, .stopped => |s| 128 +| @as(u8, @truncate(@backingInt(s))),
            .unknown => 255,
        };
    }

    /// One runner over a list (never an empty one), through the host's
    /// fair-share wrapper: `crane-measure.sh run`, or `sweep` for a whole
    /// worklist. Its journal is <out>/<name>/journal.jsonl.
    fn sweep(w: *Window, name: []const u8, runner: []const u8, list: []const []const u8, parallel: u32, extra: []const []const u8) !struct { rc: u8, dir: []const u8 } {
        std.debug.assert(list.len > 0);
        const list_path = try w.writeList(try std.fmt.allocPrint(w.arena, "{s}.list", .{name}), list);
        const dir = try w.path(name);
        const label = try std.fmt.allocPrint(w.arena, "{s}-{s}", .{ w.opts.label, name });
        var argv: std.ArrayList([]const u8) = .empty;
        const n = try std.fmt.allocPrint(w.arena, "{d}", .{parallel});
        if (w.opts.full and list.len >= 5000) {
            try argv.appendSlice(w.arena, &.{ w.measure, "sweep", label, n, list_path, dir, runner, try std.fmt.allocPrint(w.arena, "--wpt-root={s}", .{w.wpt_root}) });
        } else {
            try argv.appendSlice(w.arena, &.{ w.measure, "run", label, n, runner, try std.fmt.allocPrint(w.arena, "--wpt-root={s}", .{w.wpt_root}), try std.fmt.allocPrint(w.arena, "--output={s}", .{dir}), try std.fmt.allocPrint(w.arena, "--parallel={s}", .{n}), try std.fmt.allocPrint(w.arena, "--from-file={s}", .{list_path}) });
        }
        try argv.appendSlice(w.arena, extra);
        w.say("-- {s} START {s}: {d} files, {d} runners", .{ name, w.when(false), list.len, parallel });
        const rc = try w.child(argv.items, try std.fmt.allocPrint(w.arena, "{s}.log", .{dir}));
        return .{ .rc = rc, .dir = dir };
    }

    fn readRecords(w: *Window, dir: []const u8) ![]const journal.Record {
        const log = try journal.read(w.arena, try std.fs.path.join(w.arena, &.{ dir, "journal.jsonl" }));
        return log.records;
    }

    /// A run's records against its list, on its END line; false when it is
    /// not the list.
    fn endLine(w: *Window, name: []const u8, rc: u8, records: []const journal.Record, list: []const []const u8) !struct { complete: bool, side: Side } {
        const counted = try countSide(w.arena, records, list, false);
        var line: Io.Writer.Allocating = .init(w.arena);
        try counted.count.write(&line.writer);
        w.say("-- {s} END {s} rc={d}: {s}; OK {d}, CRASH {d}, blocking {d}, passed subtests {d}", .{ name, w.when(false), rc, line.written(), counted.side.ok, counted.side.crash, counted.side.blocking, counted.side.passed });
        return .{ .complete = counted.count.complete(), .side = counted.side };
    }
};

/// The whole A/B; its exit status.
pub fn run(arena: Allocator, io: Io, opts: Options) !Exit {
    var w: Window = .{ .arena = arena, .io = io, .opts = opts, .measure = "", .wpt_root = "" };
    const input = struct {
        fn f(win: *Window, comptime fmt: []const u8, args: anytype) Exit {
            win.say("INPUT CHECK FAILED: " ++ fmt, args);
            return .input;
        }
    }.f;
    w.say("== wpt_ab {s}: tip {s} ({s}), base {s}{s}", .{ w.when(true), opts.tip, opts.tip_commit, opts.base orelse opts.base_generation orelse "?", if (opts.dry_run) " (DRY RUN: checks only)" else "" });
    if (w.stopFile()) |f| {
        w.say("STOP ({s}) present: not started", .{f});
        return .stopped;
    }
    if (!std.fs.path.isAbsolute(opts.out)) return input(&w, "--out={s}: name it by its absolute path", .{opts.out});

    // The sides.
    const need_bug = std.mem.indexOfScalar(Step, opts.steps, .bug) != null;
    const tip = switch (try checkFrozen(arena, io, opts.tip, opts.tip_commit, need_bug)) {
        .ok => |f| f,
        .problem => |p| return input(&w, "{s}", .{p}),
    };
    w.say("check: tip {s} OK: {s}", .{ tip.dir, tip.build_info[0..@min(tip.build_info.len, 200)] });
    var base: ?Frozen = null;
    var generation: ?[]const u8 = null;
    if (opts.base) |dir| {
        if (opts.base_generation != null) return input(&w, "--base and --base-generation: one or the other", .{});
        const commit = opts.base_commit orelse return input(&w, "--base needs --base-commit=<sha>", .{});
        base = switch (try checkFrozen(arena, io, dir, commit, false)) {
            .ok => |f| f,
            .problem => |p| return input(&w, "{s}", .{p}),
        };
        w.say("check: base {s} OK: {s}", .{ base.?.dir, base.?.build_info[0..@min(base.?.build_info.len, 200)] });
        if (std.mem.eql(u8, &tip.runner_sha256, &base.?.runner_sha256)) return input(&w, "the base and the tip are one runner: the A/B compares nothing", .{});
        w.say("check: two different runners", .{});
    } else if (opts.base_generation) |dir| {
        const commit = generationCommit(dir) orelse return input(&w, "--base-generation={s}: a frozen generation is ~/crane-frozen/main-<sha>", .{dir});
        _ = switch (try checkFrozen(arena, io, dir, commit, false)) {
            .ok => |f| f,
            .problem => |p| return input(&w, "{s}", .{p}),
        };
        const j = try std.fs.path.join(arena, &.{ dir, "full", "journal.jsonl" });
        if (!exists(io, j)) return input(&w, "{s} missing: the generation's full run", .{j});
        generation = try std.fs.path.join(arena, &.{ dir, "full" });
        w.say("check: base generation {s} (main {s}): its full run, read for the listed files", .{ dir, commit });
    } else return input(&w, "a base: --base=<frozen dir> --base-commit=<sha>, or --base-generation=<frozen generation dir>", .{});

    // The tree, the wrapper.
    w.wpt_root = opts.wpt_root orelse if (opts.base_generation) |g| try std.fs.path.join(arena, &.{ g, "tests", "wpt" }) else return input(&w, "--wpt-root=<the WPT tree the runs serve> (the mirror's tests/wpt)", .{});
    if (!exists(io, try std.fs.path.join(arena, &.{ w.wpt_root, "resources", "testharness.js" }))) return input(&w, "no WPT tree at {s} (no resources/testharness.js)", .{w.wpt_root});
    w.measure = opts.measure orelse return input(&w, "--measure=<crane-measure.sh>: the host's fair-share wrapper every WPT run goes through", .{});
    if (!exists(io, w.measure)) return input(&w, "--measure={s} missing", .{w.measure});
    for (opts.crane_tests) |t| if (!exists(io, try std.fs.path.join(arena, &.{ w.wpt_root, t }))) return input(&w, "{s} is not in the served tree {s}", .{ t, w.wpt_root });

    // The lists.
    const worklist_text = Io.Dir.cwd().readFileAlloc(io, tip.worklist, arena, .limited(16 << 20)) catch |err| return input(&w, "{s}: {t}", .{ tip.worklist, err });
    const worklist = try worklistPaths(arena, worklist_text);
    var listed: std.ArrayList([]const u8) = .empty;
    if (opts.full) {
        if (opts.dirs.len > 0) return input(&w, "--full and --dirs: one or the other", .{});
        try listed.appendSlice(arena, worklist);
    } else try listed.appendSlice(arena, try pathsUnder(arena, worklist, opts.dirs));
    if (opts.files) |f| {
        const text = Io.Dir.cwd().readFileAlloc(io, f, arena, .limited(16 << 20)) catch |err| return input(&w, "--files={s}: {t}", .{ f, err });
        try listed.appendSlice(arena, try worklistPaths(arena, text));
    }
    try listed.appendSlice(arena, opts.crane_tests);
    const extra = try extraFiles(arena, io, w.wpt_root, opts.extra_dirs);
    try listed.appendSlice(arena, extra);
    const list = try sortUnique(arena, listed.items);
    if (try emptyListProblem(arena, "the A/B", list, "no worklist file under --dirs, and no --files, --crane-tests or --extra-dirs file")) |p| return input(&w, "{s}", .{p});
    const timers = try timerFiles(arena, worklist);
    w.say("check: list {d} files ({s}{s}; {d} outside the worklist from --extra-dirs); timers {d} files of the whole worklist", .{ list.len, if (opts.full) "the whole worklist" else "--dirs", if (opts.files != null) " + --files" else "", extra.len, timers.len });

    // A fresh out.
    if (exists(io, opts.out)) {
        if (!opts.move_aside) return input(&w, "{s} exists: an earlier run's records would be read as this A/B's - give it a fresh --out, or --out-exists=move-aside", .{opts.out});
        var sb: [32]u8 = undefined;
        const aside = try std.fmt.allocPrint(arena, "{s}.moved-{s}", .{ opts.out, common.utcStamp(&sb, w.nowS()) });
        try Io.Dir.cwd().rename(opts.out, Io.Dir.cwd(), aside, io);
        w.say("check: {s} existed: moved aside to {s}", .{ opts.out, aside });
    }
    if (opts.dry_run) {
        w.say("== checks passed {s} (DRY RUN: nothing run)", .{w.when(false)});
        return .clean;
    }
    try Io.Dir.cwd().createDirPath(io, opts.out);
    w.log = try Io.Dir.cwd().createFile(io, try w.path("ab.log"), .{ .exclusive = true });
    defer if (w.log) |f| f.close(io);
    _ = try w.writeList("list.txt", list);

    var steps_text: std.ArrayList(u8) = .empty;
    for (opts.steps, 0..) |st, i| {
        if (i > 0) try steps_text.append(arena, ' ');
        try steps_text.appendSlice(arena, @tagName(st));
    }
    w.say("A/B START {s}: {d} files; steps {s}; out {s}", .{ w.when(true), list.len, steps_text.items, opts.out });
    const ended = struct {
        fn f(win: *Window, code: Exit) Exit {
            win.say("A/B END {s} -> {s}: exit {d} ({t})", .{ win.when(true), win.opts.out, @backingInt(code), code });
            return code;
        }
    }.f;
    var changed: []const []const u8 = &.{};
    var tip_ab_dir: ?[]const u8 = null;
    for (opts.steps) |step| {
        if (w.stopFile()) |f| {
            w.say("STOP ({s}) before {t}", .{ f, step });
            return ended(&w, .stopped);
        }
        switch (step) {
            .ab => {
                var base_records: []const journal.Record = &.{};
                var base_run: build_compare.Run = .{};
                if (base) |b| {
                    const r = try w.sweep("ab-base", b.runner, list, opts.runners, &.{});
                    base_records = try w.readRecords(r.dir);
                    const e = try w.endLine("ab-base", r.rc, base_records, list);
                    if (!e.complete) return ended(&w, .incomplete);
                    try build_compare.loadRun(arena, &base_run, r.dir);
                } else {
                    base_records = try w.readRecords(generation.?);
                    const counted = try countSide(arena, base_records, list, true);
                    var line: Io.Writer.Allocating = .init(arena);
                    try counted.count.write(&line.writer);
                    w.say("-- ab-base (the generation's full run): {s}", .{line.written()});
                    if (!counted.count.complete()) return ended(&w, .incomplete);
                    try build_compare.loadRun(arena, &base_run, generation.?);
                }
                // Against a generation, the tip retries its failures as the
                // generation's sweep did (gen-sweep.sh; hard1's abfull.sh).
                const extra_args: []const []const u8 = if (generation) |g| try arena.dupe([]const u8, &.{try std.fmt.allocPrint(arena, "--retry-failures={s}/journal.jsonl", .{g})}) else &.{};
                const r = try w.sweep("ab-tip", tip.runner, list, opts.runners, extra_args);
                const tip_records = try w.readRecords(r.dir);
                const e = try w.endLine("ab-tip", r.rc, tip_records, list);
                if (!e.complete) return ended(&w, .incomplete);
                tip_ab_dir = r.dir;
                var tip_run: build_compare.Run = .{};
                try build_compare.loadRun(arena, &tip_run, r.dir);
                const base_side = (try countSide(arena, base_records, list, true)).side;
                const files = try fileChanges(arena, base_records, tip_records, list);
                const subs = try subtestChanges(arena, &base_run, &tip_run, list);
                changed = try changedFiles(arena, files, subs);
                _ = try w.writeList("changed.txt", changed);
                const findings = Findings.of(files);
                var report: Io.Writer.Allocating = .init(arena);
                try report.writer.print("==== THE A/B {s}: base {s} against tip {s}\n", .{ w.when(false), if (base) |b| b.commit else generationCommit(opts.base_generation.?).?, tip.commit });
                try writeSides(&report.writer, base_side, e.side);
                try report.writer.print("  files whose record changed: {d} ({d} lost subtests, {d} newly blocking, {d} new crashes); tests and subtests that differ: {d}; changed files: {d}\n", .{ files.len, findings.lost_files, findings.newly_blocking, findings.new_crashes, subs.len, changed.len });
                for (files) |f| try report.writer.print("  {s}{s} {s}: {s} {d} -> {s} {d}\n", .{ if (f.lost()) "LOST " else if (f.tip_passed > f.base_passed) "GAINED " else "", if (f.newlyBlocking()) "NEWLY-BLOCKING" else "", f.path, f.base_status, f.base_passed, f.tip_status, f.tip_passed });
                for (subs) |s| try report.writer.print("    {s} :: {s}  {s} -> {s}\n", .{ s.test_id, if (s.subtest.len > 0) s.subtest[0..@min(s.subtest.len, 160)] else "<test>", s.base, s.tip });
                const text = report.written();
                try Io.Dir.cwd().writeFile(io, .{ .sub_path = try w.path("ab-compare.txt"), .data = text });
                // The whole comparison is in ab-compare.txt; the log takes its head.
                w.say("{s}", .{text[0..@min(text.len, 64 * 1024)]});
                if (findings.any()) w.findings = true;
            },
            .bug => {
                const tip_dir = tip_ab_dir orelse {
                    w.say("== bug: no tip A/B run in this window to compare with: not run", .{});
                    return ended(&w, .incomplete);
                };
                const r = try w.sweep("bug-tip", tip.bug_runner, list, opts.runners, &.{});
                const records = try w.readRecords(r.dir);
                const e = try w.endLine("bug-tip", r.rc, records, list);
                if (!e.complete) return ended(&w, .incomplete);
                const rc = try w.child(&.{ tip.build_compare, try std.fmt.allocPrint(arena, "--production={s}", .{tip_dir}), try std.fmt.allocPrint(arena, "--bug-finding={s}", .{r.dir}), try std.fmt.allocPrint(arena, "--log={s}.log", .{r.dir}), try std.fmt.allocPrint(arena, "--known={s}", .{tip.known}) }, try w.path("bug-compare.txt"));
                const text = Io.Dir.cwd().readFileAlloc(io, try w.path("bug-compare.txt"), arena, .limited(64 << 20)) catch "";
                w.say("==== the bug-finding gate (wpt_build_compare) rc={d}:\n{s}", .{ rc, lastLines(text, 30) });
                if (rc != 0) w.findings = true;
            },
            .rerun => {
                if (try emptyListProblem(arena, "rerun", changed, "the A/B changed no file")) |p| {
                    w.say("== {s}", .{p});
                    continue;
                }
                var i: u32 = 1;
                while (i <= opts.reruns) : (i += 1) {
                    var rows: [2][]const journal.Record = undefined;
                    for ([_]bool{ false, true }, 0..) |is_tip, k| {
                        const name = try std.fmt.allocPrint(arena, "rerun{d}-{s}", .{ i, if (is_tip) "tip" else "base" });
                        const runner = if (is_tip) tip.runner else if (base) |b| b.runner else {
                            rows[k] = try w.readRecords(generation.?);
                            continue;
                        };
                        const r = try w.sweep(name, runner, changed, opts.runners, &.{});
                        rows[k] = try w.readRecords(r.dir);
                        const e = try w.endLine(name, r.rc, rows[k], changed);
                        if (!e.complete) return ended(&w, .incomplete);
                    }
                    const files = try fileChanges(arena, rows[0], rows[1], changed);
                    const f = Findings.of(files);
                    w.say("   rerun {d}: {d} of the {d} changed files differ again ({d} lost subtests, {d} newly blocking, {d} new crashes)", .{ i, files.len, changed.len, f.lost_files, f.newly_blocking, f.new_crashes });
                }
            },
            .timers => {
                if (try emptyListProblem(arena, "timers", timers, "the worklist has no " ++ timers_dir ++ "/ file")) |p| {
                    w.say("== {s}", .{p});
                    continue;
                }
                var i: u32 = 1;
                while (i <= opts.timers) : (i += 1) {
                    for ([_]bool{ false, true }) |is_tip| {
                        const runner = if (is_tip) tip.runner else if (base) |b| b.runner else continue;
                        const name = try std.fmt.allocPrint(arena, "timers{d}-{s}", .{ i, if (is_tip) "tip" else "base" });
                        const r = try w.sweep(name, runner, timers, 3, &.{});
                        const e = try w.endLine(name, r.rc, try w.readRecords(r.dir), timers);
                        if (!e.complete) return ended(&w, .incomplete);
                        if (is_tip and e.side.crash > 0) w.findings = true;
                    }
                }
            },
            .verify, .verifybase => {
                const on_base = step == .verifybase;
                var vlist: std.ArrayList([]const u8) = .empty;
                try vlist.appendSlice(arena, opts.crane_tests);
                try vlist.appendSlice(arena, changed);
                const v = try sortUnique(arena, vlist.items);
                if (try emptyListProblem(arena, @tagName(step), v, "no --crane-tests and the A/B changed no file")) |p| {
                    w.say("== {s}", .{p});
                    continue;
                }
                const runner = if (!on_base) tip.runner else if (base) |b| b.runner else {
                    w.say("== verifybase: the base is a generation's run, no runner: not run", .{});
                    continue;
                };
                const r = try w.sweep(@tagName(step), runner, v, opts.runners, &.{ try std.fmt.allocPrint(arena, "--repeat={d}", .{opts.verify_repeat}), "--verify" });
                // The runner's tally (repeat.zig): "verify<label>: STABLE over
                // N runs" or "UNSTABLE - ...", and exit 1 when unstable.
                const tally = Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ r.dir, "repeat-tally.txt" }), arena, .limited(64 << 20)) catch "";
                const stable = verifyStable(r.rc, tally);
                w.say("-- {t} END {s} rc={d} over {d} files: {s}", .{ step, w.when(false), r.rc, v.len, if (stable) "STABLE" else "NOT STABLE (its log has the unstable entries)" });
                if (!stable and !on_base) w.findings = true;
            },
        }
    }
    return ended(&w, if (w.findings) .findings else .clean);
}

/// Whether a `--repeat --verify` run was stable: it exited 0 and its tally
/// says STABLE and nothing UNSTABLE (a missing tally is not stable).
pub fn verifyStable(rc: u8, tally: []const u8) bool {
    return rc == 0 and std.mem.indexOf(u8, tally, ": STABLE over") != null and std.mem.indexOf(u8, tally, "UNSTABLE") == null;
}

/// The test files under `dirs` in the tree, outside the worklist's own
/// choice: lanes' "record dirs" (bind1, core1), with the same exclusions.
fn extraFiles(arena: Allocator, io: Io, root: []const u8, dirs: []const []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (dirs) |d| {
        const rel = std.mem.trim(u8, d, "/");
        var dir = Io.Dir.cwd().openDir(io, try std.fs.path.join(arena, &.{ root, rel }), .{ .iterate = true }) catch continue;
        defer dir.close(io);
        var walker = try dir.walk(arena);
        defer walker.deinit();
        while (try walker.next(io)) |e| {
            if (e.kind != .file) continue;
            const p = try std.fs.path.join(arena, &.{ rel, e.path });
            if (isTestFile(p)) try out.append(arena, p);
        }
    }
    return out.items;
}

/// A WPT test file by its name (the lanes' find: .html, .htm, .xhtml,
/// .any.js, .window.js, .worker.js), outside the support directories and
/// reference and manual files.
pub fn isTestFile(path: []const u8) bool {
    const exts = [_][]const u8{ ".html", ".htm", ".xhtml", ".any.js", ".window.js", ".worker.js" };
    const ok = for (exts) |e| {
        if (std.mem.endsWith(u8, path, e)) break true;
    } else false;
    if (!ok) return false;
    const excluded = [_][]const u8{ "/resources/", "/support/", "-ref.html", "-manual.", "/tools/", "/helpers", "/common/" };
    for (excluded) |x| if (std.mem.indexOf(u8, path, x) != null) return false;
    for ([_][]const u8{ "resources/", "support/", "tools/", "common/" }) |x| if (std.mem.startsWith(u8, path, x)) return false;
    return true;
}

/// The last `n` lines of `text`.
pub fn lastLines(text: []const u8, n: usize) []const u8 {
    const t = std.mem.trimEnd(u8, text, "\n");
    var seen: usize = 0;
    var i = t.len;
    while (i > 0) {
        i -= 1;
        if (t[i] == '\n') {
            seen += 1;
            if (seen == n) return t[i + 1 ..];
        }
    }
    return t;
}

// ---------------------------------------------------------------------------
// The command line.

const usage =
    \\usage: wpt_ab --tip=<frozen dir> --tip-commit=<sha>
    \\              (--base=<frozen dir> --base-commit=<sha> | --base-generation=<frozen generation dir>)
    \\              --out=<dir> [--out-exists=refuse|move-aside]
    \\              (--dirs=<prefix,...> | --full) [--extra-dirs=<prefix,...>] [--files=<list>] [--crane-tests=<path,...>]
    \\              [--steps=ab,bug,rerun,timers,verify[,verifybase]] [--runners=16] [--reruns=3] [--timers=3]
    \\              [--verify-repeat=10] [--wpt-root=<dir>] --measure=<crane-measure.sh> [--label=<lane>]
    \\              [--stop-file=<f> ...] [--dry-run]
    \\       (tests/wpt_runner/ab.zig says what each does)
    \\
;

fn valueOf(arg: []const u8, comptime name: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, arg, name ++ "=")) return arg[name.len + 1 ..];
    return null;
}

fn splitList(arena: Allocator, text: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = std.mem.tokenizeAny(u8, text, ", ");
    while (it.next()) |p| try out.append(arena, p);
    return out.items;
}

/// The options `argv` names; null (and the reason on `why`) when it is not
/// a command.
pub fn parseArgs(arena: Allocator, argv: []const []const u8, why: *[]const u8) !?Options {
    var o: Options = .{ .tip = "", .tip_commit = "", .out = "" };
    var stops: std.ArrayList([]const u8) = .empty;
    for (argv) |arg| {
        const int = struct {
            fn f(v: []const u8) ?u32 {
                return std.fmt.parseInt(u32, v, 10) catch null;
            }
        }.f;
        if (valueOf(arg, "--tip")) |v| o.tip = v else if (valueOf(arg, "--tip-commit")) |v| o.tip_commit = v else if (valueOf(arg, "--base")) |v| o.base = v else if (valueOf(arg, "--base-commit")) |v| o.base_commit = v else if (valueOf(arg, "--base-generation")) |v| o.base_generation = v else if (valueOf(arg, "--out")) |v| o.out = v else if (valueOf(arg, "--out-exists")) |v| {
            if (std.mem.eql(u8, v, "move-aside")) o.move_aside = true else if (!std.mem.eql(u8, v, "refuse")) {
                why.* = "--out-exists: refuse or move-aside";
                return null;
            }
        } else if (valueOf(arg, "--dirs")) |v| o.dirs = try splitList(arena, v) else if (std.mem.eql(u8, arg, "--full")) o.full = true else if (valueOf(arg, "--extra-dirs")) |v| o.extra_dirs = try splitList(arena, v) else if (valueOf(arg, "--files")) |v| o.files = v else if (valueOf(arg, "--crane-tests")) |v| o.crane_tests = try splitList(arena, v) else if (valueOf(arg, "--steps")) |v| {
            o.steps = parseSteps(arena, v) catch {
                why.* = "--steps: ab, bug, rerun, timers, verify, verifybase, comma-separated";
                return null;
            };
        } else if (valueOf(arg, "--runners")) |v| o.runners = int(v) orelse 0 else if (valueOf(arg, "--reruns")) |v| o.reruns = int(v) orelse 0 else if (valueOf(arg, "--timers")) |v| o.timers = int(v) orelse 0 else if (valueOf(arg, "--verify-repeat")) |v| o.verify_repeat = int(v) orelse 0 else if (valueOf(arg, "--wpt-root")) |v| o.wpt_root = v else if (valueOf(arg, "--measure")) |v| o.measure = v else if (valueOf(arg, "--label")) |v| o.label = v else if (valueOf(arg, "--stop-file")) |v| try stops.append(arena, v) else if (std.mem.eql(u8, arg, "--dry-run")) o.dry_run = true else {
            why.* = try std.fmt.allocPrint(arena, "unknown argument {s}", .{arg});
            return null;
        }
    }
    o.stop_files = stops.items;
    if (o.tip.len == 0 or o.tip_commit.len == 0 or o.out.len == 0) {
        why.* = "--tip, --tip-commit and --out are required";
        return null;
    }
    if (o.runners == 0 or o.verify_repeat == 0) {
        why.* = "--runners and --verify-repeat are whole numbers above 0";
        return null;
    }
    return o;
}

pub fn main(init: std.process.Init) !u8 {
    host.adopt(init.io);
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const args = try init.minimal.args.toSlice(arena);
    var why: []const u8 = "";
    const opts = (try parseArgs(arena, args[1..], &why)) orelse {
        std.debug.print("wpt_ab: {s}\n{s}", .{ why, usage });
        return 2;
    };
    return @backingInt(try run(arena, init.io, opts));
}

// ---------------------------------------------------------------------------

const testing = std.testing;

test "the list: --dirs takes worklist files under each directory, and an empty list is refused, never run as the whole tree" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const worklist = try worklistPaths(a, "# the 0.1 worklist\nurl/a.any.js\nurl/b.html\nurlpattern/c.any.js\n\nhtml/webappapis/timers/negative-settimeout.any.js\n");
    try testing.expectEqual(@as(usize, 4), worklist.len);
    const url = try pathsUnder(a, worklist, &.{"url"});
    try testing.expectEqual(@as(usize, 2), url.len);
    // "url" does not take "urlpattern/", and "url/" names the same directory.
    try testing.expectEqual(@as(usize, 2), (try pathsUnder(a, worklist, &.{"url/"})).len);
    try testing.expectEqual(@as(?[]const u8, null), try emptyListProblem(a, "the A/B", url, "-"));
    // hard1-usp, 2026-11-25: a directory with no worklist file.
    const none = try pathsUnder(a, worklist, &.{"no-such-dir"});
    const why = (try emptyListProblem(a, "the A/B", none, "no worklist file under --dirs")).?;
    try testing.expect(std.mem.indexOf(u8, why, "runs the whole tree") != null);
    try testing.expect(std.mem.startsWith(u8, why, "the A/B: the file list is empty"));
}

test "the timer files come from the WHOLE worklist, whatever the A/B's own list; a worklist without one gives an empty list the step refuses" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const worklist = try worklistPaths(a, "url/a.any.js\nhtml/webappapis/timers/negative-settimeout.any.js\nhtml/webappapis/timers/evil-spec-example.any.js\nhtml/webappapis/timersx/other.html\n");
    // A targeted url/ list holds no timer file (hard1-usp's window took its
    // timers from it and ran the whole tree for 70 minutes).
    try testing.expectEqual(@as(usize, 0), (try timerFiles(a, try pathsUnder(a, worklist, &.{"url"}))).len);
    const timers = try timerFiles(a, worklist);
    try testing.expectEqual(@as(usize, 2), timers.len);
    try testing.expectEqualStrings("html/webappapis/timers/negative-settimeout.any.js", timers[0]);
    const none = try timerFiles(a, try worklistPaths(a, "url/a.any.js\n"));
    try testing.expect((try emptyListProblem(a, "timers", none, "the worklist has no timer file")) != null);
}

fn rec(path: []const u8, status: journal.Status, passed: usize, failed: usize) journal.Record {
    return .{ .index = 0, .path = path, .status = status, .passed = passed, .failed = failed };
}

test "a run's records against its list: complete, or INCOMPLETE with what is missing, twice or not listed" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const list = [_][]const u8{ "url/a.any.js", "url/b.html", "url/c.html" };
    const whole = [_]journal.Record{ rec("url/a.any.js", .ok, 10, 0), rec("url/b.html", .ok, 0, 3), rec("url/c.html", .crash, 0, 0) };
    const c = try countSide(a, &whole, &list, false);
    try testing.expect(c.count.complete());
    try testing.expectEqual(@as(u32, 2), c.side.ok);
    try testing.expectEqual(@as(u32, 1), c.side.crash);
    // b.html is OK with nothing passing, c.html crashed: both block.
    try testing.expectEqual(@as(u32, 2), c.side.blocking);
    try testing.expectEqual(@as(u64, 10), c.side.passed);
    var line: Io.Writer.Allocating = .init(a);
    try c.count.write(&line.writer);
    try testing.expectEqualStrings("3 of 3 listed files have a record", line.written());

    // A run cut short: one file missing, one recorded twice, one of another list.
    const short = [_]journal.Record{ rec("url/a.any.js", .ok, 10, 0), rec("url/a.any.js", .ok, 10, 0), rec("dom/x.html", .ok, 1, 0) };
    const s = try countSide(a, &short, &list, false);
    try testing.expect(!s.count.complete());
    var line2: Io.Writer.Allocating = .init(a);
    try s.count.write(&line2.writer);
    try testing.expectEqualStrings("1 of 3 listed files have a record - INCOMPLETE: 2 missing (the first: url/b.html) 1 recorded twice 1 not on the list (the first: dom/x.html: another run's records?)", line2.written());
    // A generation's full run as the base: its other files are not unlisted.
    const g = try countSide(a, &[_]journal.Record{ rec("dom/x.html", .ok, 1, 0), whole[0], whole[1], whole[2] }, &list, true);
    try testing.expect(g.count.complete());
}

test "the comparison: files that lost subtests, newly blocking or crashing, and each test and subtest that changed, named by its source file" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const list = [_][]const u8{ "url/a.any.js", "url/b.html", "url/c.html", "url/d.html" };
    const base = [_]journal.Record{ rec("url/a.any.js", .ok, 10, 0), rec("url/b.html", .ok, 3, 0), rec("url/c.html", .ok, 5, 0), rec("url/d.html", .ok, 2, 2) };
    const tip = [_]journal.Record{ rec("url/a.any.js", .ok, 9, 1), rec("url/b.html", .ok, 0, 3), rec("url/c.html", .crash, 0, 0), rec("url/d.html", .ok, 4, 0) };
    const files = try fileChanges(a, &base, &tip, &list);
    try testing.expectEqual(@as(usize, 4), files.len);
    const f = Findings.of(files);
    try testing.expectEqual(@as(u32, 3), f.lost_files);
    // b.html: OK with nothing passing now. c.html: a crash.
    try testing.expectEqual(@as(u32, 2), f.newly_blocking);
    try testing.expectEqual(@as(u32, 1), f.new_crashes);
    try testing.expect(f.any());
    try testing.expect(!Findings.of(files[3..]).any());

    // The result streams: a generated test is named by its source file.
    var b_run: build_compare.Run = .{};
    var t_run: build_compare.Run = .{};
    try b_run.addStream(a,
        \\{"test":"/url/a.any.worker.html","status":"OK","subtests":[{"name":"x","status":"PASS"},{"name":"y","status":"PASS"}]}
        \\{"test":"/dom/z.html","status":"OK","subtests":[{"name":"q","status":"PASS"}]}
    );
    try t_run.addStream(a,
        \\{"test":"/url/a.any.worker.html","status":"OK","subtests":[{"name":"x","status":"PASS"},{"name":"y","status":"FAIL"}]}
        \\{"test":"/dom/z.html","status":"OK","subtests":[{"name":"q","status":"FAIL"}]}
    );
    const subs = try subtestChanges(a, &b_run, &t_run, &list);
    // dom/z.html is not on the list.
    try testing.expectEqual(@as(usize, 1), subs.len);
    try testing.expectEqualStrings("url/a.any.js", subs[0].source);
    try testing.expectEqualStrings("y", subs[0].subtest);
    const changed = try changedFiles(a, files, subs);
    try testing.expectEqual(@as(usize, 4), changed.len);
    try testing.expectEqualStrings("url/a.any.js", changed[0]);
}

test "the A/B's summary lines" {
    var buf: [512]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try writeSides(&w, .{ .files = 3, .ok = 3, .passed = 15, .blocking = 0 }, .{ .files = 3, .ok = 2, .crash = 1, .passed = 13, .blocking = 2 });
    try testing.expectEqualStrings(
        \\  files: base 3 tip 3; OK 3 -> 2; ERROR 0 -> 0; TIMEOUT 0 -> 0; CRASH 0 -> 1
        \\  passed subtests: base 15 tip 13 (-2); blocking files: base 0 tip 2 (+2)
        \\
    , w.buffered());
}

test "a verify run is stable only when it exited 0 and its tally says so" {
    try testing.expect(verifyStable(0, "verify: STABLE over 10 runs (every file, harness status and subtest had one status in every run)\n"));
    try testing.expect(verifyStable(0, "verify (tip): STABLE over 10 runs\n"));
    try testing.expect(!verifyStable(1, "verify: UNSTABLE - 1 with a status that differs between the 10 runs:\n"));
    try testing.expect(!verifyStable(0, ""));
    try testing.expect(!verifyStable(1, "verify: STABLE over 10 runs\n"));
}

test "a test URL's source file" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualStrings("url/a.any.js", try sourceOf(a, "/url/a.any.html"));
    try testing.expectEqualStrings("url/a.any.js", try sourceOf(a, "/url/a.any.sharedworker.html?x=1"));
    try testing.expectEqualStrings("url/a.window.js", try sourceOf(a, "/url/a.window.html"));
    try testing.expectEqualStrings("url/a.worker.js", try sourceOf(a, "/url/a.worker.html"));
    try testing.expectEqualStrings("url/b.html", try sourceOf(a, "/url/b.html#frag"));
}

test "a frozen generation is named by its directory; a WPT test file by its name" {
    try testing.expectEqualStrings("f8e6c08c23", generationCommit("/home/u/crane-frozen/main-f8e6c08c23").?);
    try testing.expectEqual(@as(?[]const u8, null), generationCommit("/home/u/crane-frozen/latest"));
    try testing.expect(isTestFile("webaudio/a.html"));
    try testing.expect(isTestFile("webaudio/b.any.js"));
    try testing.expect(!isTestFile("webaudio/resources/c.html"));
    try testing.expect(!isTestFile("webaudio/d-ref.html"));
    try testing.expect(!isTestFile("webaudio/e.js"));
}

test "a frozen dir: its runners' sums, its worklist, its commit; nested or flat" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(io, "zig-out/bin");
    var sums: Io.Writer.Allocating = .init(a);
    for (bug_files) |f| {
        try tmp.dir.writeFile(io, .{ .sub_path = try std.fs.path.join(a, &.{ "zig-out/bin", f }), .data = f });
        var hex: [64]u8 = undefined;
        const root = try tmp.dir.realPathFileAlloc(io, ".", a);
        try common.sha256File(io, try std.fs.path.join(a, &.{ root, "zig-out/bin", f }), &hex);
        try sums.writer.print("{s}  {s}\n", .{ &hex, f });
    }
    try tmp.dir.writeFile(io, .{ .sub_path = "zig-out/bin/SHA256SUMS", .data = sums.written() });
    try tmp.dir.writeFile(io, .{ .sub_path = "worklist.txt", .data = "url/a.any.js\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "wpt_build_differences.txt", .data = "" });
    try tmp.dir.writeFile(io, .{ .sub_path = "BUILD_INFO", .data = "tree=lane/tool1-ab 97ab1aaf2 built on server1\n" });
    const dir = try tmp.dir.realPathFileAlloc(io, ".", a);
    const ok = (try checkFrozen(a, io, dir, "97ab1aaf2", true)).ok;
    try testing.expect(std.mem.endsWith(u8, ok.runner, "zig-out/bin/wpt_runner"));
    try testing.expect(std.mem.indexOf(u8, (try checkFrozen(a, io, dir, "0aa42fcdc", true)).problem, "does not name commit 0aa42fcdc") != null);
    try tmp.dir.deleteFile(io, "worklist.txt");
    try testing.expect(std.mem.indexOf(u8, (try checkFrozen(a, io, dir, "97ab1aaf2", true)).problem, "worklist.txt missing") != null);
}

test "the command line: required options, steps, and what is refused" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var why: []const u8 = "";
    const o = (try parseArgs(a, &.{ "--tip=/t", "--tip-commit=97ab1aaf2", "--base-generation=/g/main-f8e6c08c23", "--out=/o", "--dirs=url,dom/nodes", "--steps=ab,timers,rerun", "--timers=1", "--stop-file=/s1", "--stop-file=/s2" }, &why)).?;
    try testing.expectEqual(@as(usize, 2), o.dirs.len);
    try testing.expectEqualSlices(Step, &.{ .ab, .timers, .rerun }, o.steps);
    try testing.expectEqual(@as(u32, 1), o.timers);
    try testing.expectEqual(@as(usize, 2), o.stop_files.len);
    try testing.expectEqual(@as(?Options, null), try parseArgs(a, &.{"--tip=/t"}, &why));
    try testing.expectEqual(@as(?Options, null), try parseArgs(a, &.{ "--tip=/t", "--tip-commit=x", "--out=/o", "--steps=ab,cost" }, &why));
    try testing.expectEqual(@as(?Options, null), try parseArgs(a, &.{ "--tip=/t", "--tip-commit=x", "--out=/o", "--bogus" }, &why));
    try testing.expectEqualStrings("unknown argument --bogus", why);
}
