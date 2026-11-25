//! `perf_bench window`: a lane's cost window, run the way docs/performance.md
//! ("A lane's cost pair") says, in one committed tool (lane tool1,
//! 2026-11-24). It replaces the per-lane costwin.sh copies (vm1 -> edit4 ->
//! tpc -> mem1 -> hard1 -> cs1), whose faults it exists to refuse:
//!
//! - an OUT an earlier run left (hard1, 2026-11-24: a window re-queued under
//!   the same name after a cancel printed a verdict over the cancelled run's
//!   52 records) is refused, or moved aside with a stamp;
//! - each pass's records are counted against runs x workloads x consoles,
//!   one per (engine, workload, run), before any verdict is printed;
//! - a pass that perf_bench run ended early - a STOP file (exit 3) or its
//!   guard, N launches of one engine in a row timed out or crashed (exit 4;
//!   2026-11-23: a broken console timed out every workload for 7 h) - ends
//!   the window with no verdict;
//! - each console is checked against its SHA256SUMS, its modes and its CPU
//!   target, and `perf_bench check` launches one page in each before the
//!   window starts;
//! - a mirror whose tree.head is not the measured tip is refused unless the
//!   window is told the exact reason;
//! - every line a person reads has its time from the clock, 12-hour US
//!   Eastern (AGENTS.md, "Times are US Eastern").
//!
//!   perf_bench window --tip=<console dir> --tip-commit=<sha>
//!       [--base=<console dir> --base-commit=<sha> | --alone]
//!       --out=<dir> [--out-exists=refuse|move-aside]
//!       [--tree-head=<file> [--tree-differs=<reason>]]
//!       [--steps=D,M,C] [--runs=7] [--memory-runs=9] [--round=10]
//!       [--suite=tests/perf/suite.json] [--root=tests/perf] [--only=<text>]
//!       [--stop-file=<f> ...] [--load-max=3] [--quiet-wait-s=3600]
//!       [--max-timeouts=3] [--check-timeout-s=60] [--any-host] [--dry-run]
//!
//! A console dir is a frozen release console: repl, repl.modes,
//! whatwg_snapshot.bin (and gc_bench, perf_bench), SHA256SUMS over them,
//! and BUILD_INFO naming the commit it was built from and `v8=<version>`.
//! Steps: D the default pass (time, CPU, instructions), M the memory pass
//! (MallocLargeCache=0 MallocMaxMagazines=1, --collected), C the verdict
//! (`perf_bench cost`). Exit: 0 within the bar; 1 the cost verdict is over
//! the bar; 2 an input check failed; 3 a STOP file; 4 a pass is incomplete
//! (no verdict); 5 the host never went quiet.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const journal = @import("journal.zig");
const suite_mod = @import("suite.zig");
const engines = @import("engines.zig");
const runner = @import("runner.zig");

pub const Exit = enum(u8) {
    within = 0,
    over = 1,
    input = 2,
    stopped = 3,
    incomplete = 4,
    not_quiet = 5,
};

pub const Step = enum {
    /// The default pass.
    D,
    /// The memory pass.
    M,
    /// The verdict.
    C,
};

pub const Options = struct {
    tip: []const u8,
    tip_commit: []const u8,
    base: ?[]const u8 = null,
    base_commit: ?[]const u8 = null,
    out: []const u8,
    move_aside: bool = false,
    tree_head: ?[]const u8 = null,
    tree_differs: ?[]const u8 = null,
    steps: []const Step = &.{ .D, .M, .C },
    runs: u32 = 7,
    memory_runs: u32 = 9,
    round: u32 = 10,
    suite_path: []const u8 = "tests/perf/suite.json",
    root: []const u8 = "tests/perf",
    only: ?[]const u8 = null,
    stop_files: []const []const u8 = &.{},
    load_max: f64 = 3,
    quiet_wait_s: u32 = 3600,
    max_timeouts: u32 = 3,
    check_timeout_s: u32 = 60,
    any_host: bool = false,
    dry_run: bool = false,
    /// The host a cost pair is timed on.
    timing_host: []const u8 = "chat",
};

/// "D,M,C" (or "D M C"): the steps, in order.
pub fn parseSteps(arena: Allocator, text: []const u8) error{ OutOfMemory, UnknownStep, NoSteps }![]const Step {
    var out: std.ArrayList(Step) = .empty;
    var it = std.mem.tokenizeAny(u8, text, ", ");
    while (it.next()) |name| try out.append(arena, std.meta.stringToEnum(Step, name) orelse return error.UnknownStep);
    if (out.items.len == 0) return error.NoSteps;
    return out.items;
}

// ---------------------------------------------------------------------------
// The clock: 12-hour US Eastern.

/// Days from 1970-01-01 to the civil date (proleptic Gregorian; Howard
/// Hinnant's days_from_civil).
pub fn daysFromCivil(year: i64, month: u32, day: u32) i64 {
    const y = if (month <= 2) year - 1 else year;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const m: i64 = month;
    const mp = if (m > 2) m - 3 else m + 9;
    const doy = @divFloor(153 * mp + 2, 5) + @as(i64, day) - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

/// The day of the month of the `nth` Sunday of `month` (1-based).
fn nthSunday(year: i64, month: u32, nth: u32) u32 {
    // 1970-01-01 was a Thursday: weekday 0 = Sunday.
    const first = daysFromCivil(year, month, 1);
    const weekday: u32 = @intCast(@mod(first + 4, 7));
    const first_sunday = 1 + (7 - weekday) % 7;
    return first_sunday + 7 * (nth - 1);
}

/// US Eastern's offset from UTC at `utc_s`, in hours: -4 in daylight time
/// (since 2007: from the second Sunday of March, 2:00 AM standard time, to
/// the first Sunday of November, 2:00 AM daylight time), else -5.
pub fn easternOffsetHours(utc_s: i64) i64 {
    const day = @divFloor(utc_s, std.time.s_per_day);
    const es: std.time.epoch.EpochDay = .{ .day = @intCast(day) };
    const year: i64 = es.calculateYearDay().year;
    const start = daysFromCivil(year, 3, nthSunday(year, 3, 2)) * std.time.s_per_day + 7 * 3600;
    const end = daysFromCivil(year, 11, nthSunday(year, 11, 1)) * std.time.s_per_day + 6 * 3600;
    return if (utc_s >= start and utc_s < end) -4 else -5;
}

/// A clock reading for a person: "10:06 PM ET"; with `date`,
/// "10:06 PM ET 2026-11-24" (the Eastern date).
pub fn easternTime(buf: []u8, utc_s: i64, date: bool) []const u8 {
    const local = utc_s + easternOffsetHours(utc_s) * 3600;
    const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(local) };
    const ds = es.getDaySeconds();
    const h24 = ds.getHoursIntoDay();
    const h12 = if (h24 % 12 == 0) 12 else h24 % 12;
    const half = if (h24 < 12) "AM" else "PM";
    if (!date) return std.fmt.bufPrint(buf, "{d}:{d:0>2} {s} ET", .{ h12, ds.getMinutesIntoHour(), half }) catch buf[0..0];
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d}:{d:0>2} {s} ET {d}-{d:0>2}-{d:0>2}", .{ h12, ds.getMinutesIntoHour(), half, yd.year, md.month.numeric(), md.day_index + 1 }) catch buf[0..0];
}

/// "20261124T220600Z": a UTC stamp for a name (data, not for a person).
pub fn utcStamp(buf: []u8, utc_s: i64) []const u8 {
    const es: std.time.epoch.EpochSeconds = .{ .secs = @intCast(utc_s) };
    const ds = es.getDaySeconds();
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d}{d:0>2}{d:0>2}T{d:0>2}{d:0>2}{d:0>2}Z", .{ yd.year, md.month.numeric(), md.day_index + 1, ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute() }) catch buf[0..0];
}

// ---------------------------------------------------------------------------
// Commits, consoles and the record count: what the window checks.

fn isHex(c: u8) bool {
    return std.ascii.isDigit(c) or (c >= 'a' and c <= 'f');
}

/// Whether two abbreviations name one commit: both at least 7 hex digits,
/// the shorter a prefix of the longer.
pub fn sameCommit(a: []const u8, b: []const u8) bool {
    const x = std.mem.trim(u8, a, " \t\r\n");
    const y = std.mem.trim(u8, b, " \t\r\n");
    if (x.len < 7 or y.len < 7) return false;
    for (x) |c| if (!isHex(c)) return false;
    for (y) |c| if (!isHex(c)) return false;
    const n = @min(x.len, y.len);
    return std.mem.eql(u8, x[0..n], y[0..n]);
}

/// Whether `text` names `commit` (any run of hex digits that is the same
/// commit, `sameCommit`).
pub fn mentionsCommit(text: []const u8, commit: []const u8) bool {
    var i: usize = 0;
    while (i < text.len) {
        if (!isHex(text[i])) {
            i += 1;
            continue;
        }
        const start = i;
        while (i < text.len and isHex(text[i])) i += 1;
        // A whole token: not part of a longer word ("deadbeefcafe" in
        // "xdeadbeefcafe" is not a sha).
        const before_ok = start == 0 or !std.ascii.isAlphanumeric(text[start - 1]);
        const after_ok = i == text.len or !std.ascii.isAlphanumeric(text[i]);
        if (before_ok and after_ok and sameCommit(text[start..i], commit)) return true;
    }
    return false;
}

/// BUILD_INFO's `v8=<version>`.
pub fn v8Of(build_info: []const u8) ?[]const u8 {
    var it = std.mem.tokenizeAny(u8, build_info, " \t\r\n,;");
    while (it.next()) |tok| if (std.mem.startsWith(u8, tok, "v8=") and tok.len > 3) return tok[3..];
    return null;
}

/// The release console's modes, as `repl.modes` names them: its first
/// line, and a CPU target of the fixed model (docs/performance.md, "The CPU
/// target": the model, then +/- features, never native).
pub fn modesProblem(modes: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, std.mem.trimEnd(u8, modes, "\n"), '\n');
    const optimize = lines.next() orelse return "repl.modes is empty";
    const cpu = lines.next() orelse return "repl.modes has no target_cpu line";
    if (lines.next() != null) return "repl.modes has more than its two lines";
    if (!std.mem.startsWith(u8, optimize, "optimize=") or !std.mem.eql(u8, optimize["optimize=".len..], engines.craneModes(.crane))) return "repl.modes is not the ReleaseSafe release build";
    const prefix = "target_cpu=apple_m1";
    if (!std.mem.startsWith(u8, cpu, prefix)) return "repl.modes is not built for apple_m1";
    const rest = cpu[prefix.len..];
    var i: usize = 0;
    while (i < rest.len) {
        if (rest[i] != '+' and rest[i] != '-') return "repl.modes' target is not apple_m1 with features (a native build, or another model)";
        i += 1;
        const start = i;
        while (i < rest.len and (std.ascii.isLower(rest[i]) or std.ascii.isDigit(rest[i]) or rest[i] == '_')) i += 1;
        if (i == start) return "repl.modes' target has an empty feature";
    }
    return null;
}

/// One SHA256SUMS line: "<hex>  <file>" (shasum's output; "*" before the
/// name in binary mode).
pub const SumLine = struct { sha256: []const u8, file: []const u8 };

pub fn parseSums(arena: Allocator, text: []const u8) error{ OutOfMemory, BadSumsLine }![]const SumLine {
    var out: std.ArrayList(SumLine) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        const sp = std.mem.indexOfAny(u8, line, " \t") orelse return error.BadSumsLine;
        const sha = line[0..sp];
        var name = std.mem.trimStart(u8, line[sp..], " \t");
        if (name.len > 0 and name[0] == '*') name = name[1..];
        if (!journal.isSha256(sha) or name.len == 0 or std.mem.indexOfScalar(u8, name, '/') != null) return error.BadSumsLine;
        try out.append(arena, .{ .sha256 = sha, .file = name });
    }
    return out.items;
}

/// The files a console's SHA256SUMS must cover.
pub const console_files = [_][]const u8{ "repl", "repl.modes", "whatwg_snapshot.bin" };

/// What a checked console dir is.
pub const Console = struct {
    dir: []const u8,
    commit: []const u8,
    repl_sha256: []const u8,
    optimize: []const u8,
    target_cpu: []const u8,
    v8: []const u8,
    build_info: []const u8,
};

/// A check's answer: the value, or why not.
pub fn Checked(comptime T: type) type {
    return union(enum) { ok: T, problem: []const u8 };
}

/// `dir` as a window's side: its SHA256SUMS hold (every file listed matches,
/// and repl, repl.modes and whatwg_snapshot.bin are listed), its modes are
/// the release build's for apple_m1, its BUILD_INFO names `commit` and a
/// V8 whose version the console's bytes hold.
pub fn checkConsole(arena: Allocator, io: Io, dir: []const u8, commit: []const u8) !Checked(Console) {
    const bad = struct {
        fn f(a: Allocator, comptime fmt: []const u8, args: anytype) !Checked(Console) {
            return .{ .problem = try std.fmt.allocPrint(a, fmt, args) };
        }
    }.f;
    if (!std.fs.path.isAbsolute(dir)) return bad(arena, "{s}: a console dir is named by its absolute path (the pins name its binary)", .{dir});
    const read = struct {
        fn f(a: Allocator, i: Io, d: []const u8, name: []const u8) ?[]const u8 {
            const p = std.fs.path.join(a, &.{ d, name }) catch return null;
            return Io.Dir.cwd().readFileAlloc(i, p, a, .limited(1 << 20)) catch null;
        }
    }.f;
    const sums_text = read(arena, io, dir, "SHA256SUMS") orelse return bad(arena, "{s}/SHA256SUMS missing", .{dir});
    const sums = parseSums(arena, sums_text) catch return bad(arena, "{s}/SHA256SUMS: a line is not \"<sha256>  <file>\"", .{dir});
    for (console_files) |need| {
        for (sums) |s| {
            if (std.mem.eql(u8, s.file, need)) break;
        } else return bad(arena, "{s}/SHA256SUMS does not cover {s}", .{ dir, need });
    }
    var repl_sha: []const u8 = "";
    for (sums) |s| {
        const p = try std.fs.path.join(arena, &.{ dir, s.file });
        var hex: [64]u8 = undefined;
        engines.sha256File(io, p, &hex) catch |err| return bad(arena, "{s}: {t}", .{ p, err });
        if (!std.mem.eql(u8, &hex, s.sha256)) return bad(arena, "{s} does not match its SHA256SUMS (sha256 {s}, listed {s})", .{ p, &hex, s.sha256 });
        if (std.mem.eql(u8, s.file, "repl")) repl_sha = try arena.dupe(u8, &hex);
    }
    const modes = read(arena, io, dir, "repl.modes") orelse return bad(arena, "{s}/repl.modes unreadable", .{dir});
    if (modesProblem(modes)) |p| return bad(arena, "{s}: {s}: {s}", .{ dir, p, std.mem.trim(u8, modes, "\n") });
    var lines = std.mem.splitScalar(u8, std.mem.trimEnd(u8, modes, "\n"), '\n');
    const optimize = lines.next().?["optimize=".len..];
    const target_cpu = lines.next().?["target_cpu=".len..];
    const info = read(arena, io, dir, "BUILD_INFO") orelse return bad(arena, "{s}/BUILD_INFO missing: what the console was built from is not said", .{dir});
    if (!mentionsCommit(info, commit)) return bad(arena, "{s}/BUILD_INFO does not name commit {s}: {s}", .{ dir, commit, std.mem.trim(u8, info, "\n") });
    const v8 = v8Of(info) orelse return bad(arena, "{s}/BUILD_INFO names no v8=<version>", .{dir});
    const repl_path = try std.fs.path.join(arena, &.{ dir, "repl" });
    if (!(fileContains(arena, io, repl_path, v8) catch false)) return bad(arena, "{s} does not hold the string {s}: not that V8", .{ repl_path, v8 });
    return .{ .ok = .{ .dir = dir, .commit = commit, .repl_sha256 = repl_sha, .optimize = optimize, .target_cpu = target_cpu, .v8 = v8, .build_info = std.mem.trim(u8, info, " \t\r\n") } };
}

/// Whether the file at `path` holds `needle` (read in pieces that overlap
/// by the needle's length; the piece from `gpa`, never the stack:
/// tools/lint_stack_arrays.zig).
pub fn fileContains(gpa: Allocator, io: Io, path: []const u8, needle: []const u8) !bool {
    if (needle.len == 0) return true;
    var file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const buf = try gpa.alloc(u8, 256 * 1024);
    defer gpa.free(buf);
    var rbuf: [4096]u8 = undefined;
    var reader = file.reader(io, &rbuf);
    var kept: usize = 0;
    while (true) {
        const n = reader.interface.readSliceShort(buf[kept..]) catch |err| return err;
        const have = kept + n;
        if (std.mem.indexOf(u8, buf[0..have], needle) != null) return true;
        if (n == 0) return false;
        kept = @min(needle.len - 1, have);
        std.mem.copyForwards(u8, buf[0..kept], buf[have - kept .. have]);
    }
}

/// A pin of a checked console, as the window writes it.
pub fn pinText(arena: Allocator, name: engines.Name, c: Console, installed: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena,
        \\name={s}
        \\version={s}
        \\commit={s}
        \\build=release: -Dwpt-runner-release -Dcpu=apple_m1 (ReleaseSafe everywhere, C .trap, libc malloc); {s}
        \\optimize={s}
        \\target_cpu={s}
        \\v8={s} static
        \\binary={s}/repl
        \\sha256={s}
        \\installed={s}
        \\
    , .{ @tagName(name), c.commit, c.commit, c.build_info[0..@min(c.build_info.len, 200)], c.optimize, c.target_cpu, c.v8, c.dir, c.repl_sha256, installed });
}

/// The mirror's tree.head against the measured tip: null when they are one
/// commit, or when told why not (`reason`); else the problem.
pub fn treeHeadProblem(arena: Allocator, tree_head: []const u8, tip_commit: []const u8, reason: ?[]const u8) !?[]const u8 {
    const head = std.mem.trim(u8, tree_head, " \t\r\n");
    if (sameCommit(head, tip_commit)) return null;
    if (reason) |r| if (std.mem.trim(u8, r, " \t").len > 0) return null;
    return try std.fmt.allocPrint(arena, "the mirror's tree is {s}, the measured tip {s}: its pages (tests/perf) are not the tip's - re-sync the mirror, or say why with --tree-differs=<reason>", .{ head, tip_commit });
}

/// One pass's records against what it should hold.
pub const Count = struct {
    expected: u32 = 0,
    /// Records of a selected workload, of a pinned engine.
    found: u32 = 0,
    not_ok: u32 = 0,
    /// (engine, workload, run) with no record, and with two.
    missing: u32 = 0,
    duplicate: u32 = 0,
    /// Records of an engine the window did not pin, or a run beyond its
    /// runs: another window's.
    foreign: u32 = 0,
    first_missing: []const u8 = "",

    pub fn complete(c: Count) bool {
        return c.found == c.expected and c.missing == 0 and c.duplicate == 0 and c.foreign == 0;
    }
};

/// The selected workloads of `s` (`--only` selects whole pages): the
/// records a launch makes for itself, its page's own row (`page.<file>`)
/// aside - a launch that timed out writes none.
pub fn selectedWorkloads(arena: Allocator, s: suite_mod.Suite, only: ?[]const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (s.pages) |p| if (runner.pageSelected(p, only)) try out.appendSlice(arena, p.workloads);
    return out.items;
}

/// `records` counted against runs x workloads x consoles: exactly one per
/// (engine, workload, run).
pub fn countRecords(arena: Allocator, records: []const journal.Record, workloads: []const []const u8, runs: u32, sides: []const engines.Name) !Count {
    var c: Count = .{ .expected = @intCast(workloads.len * runs * sides.len) };
    const seen = try arena.alloc(u32, workloads.len * runs * sides.len);
    @memset(seen, 0);
    for (records) |r| {
        const wi = for (workloads, 0..) |w, i| {
            if (std.mem.eql(u8, w, r.workload)) break i;
        } else continue;
        const si = for (sides, 0..) |s, i| {
            if (s == r.engine.name) break i;
        } else {
            c.foreign += 1;
            continue;
        };
        if (r.run >= runs) {
            c.foreign += 1;
            continue;
        }
        c.found += 1;
        if (r.status != .ok) c.not_ok += 1;
        seen[(si * runs + r.run) * workloads.len + wi] += 1;
    }
    for (sides, 0..) |s, si| for (0..runs) |ri| for (workloads, 0..) |w, wi| {
        const n = seen[(si * runs + ri) * workloads.len + wi];
        if (n == 0) {
            if (c.missing == 0) c.first_missing = try std.fmt.allocPrint(arena, "{s} {s} run {d}", .{ @tagName(s), w, ri });
            c.missing += 1;
        } else if (n > 1) c.duplicate += n - 1;
    };
    return c;
}

/// The END line's count: "532 of 532 records (7 runs x 38 workloads x 2
/// consoles), 0 not ok" and what is wrong when it is not complete.
pub fn writeCount(w: *Io.Writer, c: Count, runs: u32, workloads: usize, consoles: usize) !void {
    try w.print("{d} of {d} records ({d} runs x {d} workloads x {d} consoles), {d} not ok", .{ c.found, c.expected, runs, workloads, consoles, c.not_ok });
    if (c.complete()) return;
    try w.writeAll(" - INCOMPLETE:");
    if (c.missing > 0) try w.print(" {d} missing (the first: {s})", .{ c.missing, c.first_missing });
    if (c.duplicate > 0) try w.print(" {d} duplicated", .{c.duplicate});
    if (c.foreign > 0) try w.print(" {d} of another window (an engine or a run this window did not pin)", .{c.foreign});
}

// ---------------------------------------------------------------------------
// The window.

extern "c" fn getloadavg(loadavg: [*]f64, nelem: c_int) c_int;

/// The host's 1-minute load; null when it cannot be read.
fn loadNow() ?f64 {
    var l: [3]f64 = undefined;
    if (getloadavg(&l, 3) < 1) return null;
    return l[0];
}

const Window = struct {
    gpa: Allocator,
    arena: Allocator,
    io: Io,
    opts: Options,
    environ: *const std.process.Environ.Map,
    self_exe: []const u8,
    log: ?Io.File = null,

    fn nowS(w: *const Window) i64 {
        return @intCast(@divFloor(Io.Clock.real.now(w.io).nanoseconds, std.time.ns_per_s));
    }

    fn when(w: *const Window, date: bool) []const u8 {
        const buf = w.arena.alloc(u8, 48) catch return "?";
        return easternTime(buf, w.nowS(), date);
    }

    /// One line to stdout and the window's log.
    fn say(w: *Window, comptime fmt: []const u8, args: anytype) void {
        const text = std.fmt.allocPrint(w.arena, fmt ++ "\n", args) catch return;
        Io.File.stdout().writeStreamingAll(w.io, text) catch {};
        if (w.log) |f| f.writeStreamingAll(w.io, text) catch {};
    }

    fn stopFile(w: *const Window) ?[]const u8 {
        for (w.opts.stop_files) |f| {
            if (Io.Dir.cwd().access(w.io, f, .{})) |_| return f else |_| {}
        }
        return null;
    }

    fn loadText(w: *const Window) []const u8 {
        const l = loadNow() orelse return "unknown";
        return std.fmt.allocPrint(w.arena, "{d:.2}", .{l}) catch "?";
    }

    /// Runs this binary with `args`, its output to `log_path` (and, with
    /// `echo`, then to stdout); its exit status (128 + n for signal n).
    fn child(w: *Window, args: []const []const u8, log_path: []const u8, env: ?*const std.process.Environ.Map, echo: bool) !u8 {
        const argv = try w.arena.alloc([]const u8, args.len + 1);
        argv[0] = w.self_exe;
        @memcpy(argv[1..], args);
        var file = try Io.Dir.cwd().createFile(w.io, log_path, .{ .exclusive = true });
        defer file.close(w.io);
        var c = try std.process.spawn(w.io, .{
            .argv = argv,
            .environ_map = env orelse w.environ,
            .stdin = .ignore,
            .stdout = .{ .file = file },
            .stderr = .{ .file = file },
        });
        const term = try c.wait(w.io);
        if (echo) {
            const text = Io.Dir.cwd().readFileAlloc(w.io, log_path, w.arena, .limited(64 << 20)) catch "";
            Io.File.stdout().writeStreamingAll(w.io, text) catch {};
            if (w.log) |f| f.writeStreamingAll(w.io, text) catch {};
        }
        return switch (term) {
            .exited => |code| code,
            .signal, .stopped => |s| 128 +| @as(u8, @truncate(@backingInt(s))),
            .unknown => 255,
        };
    }

    /// Waits for a quiet host before `step`.
    fn quietGate(w: *Window, step: Step) ?Exit {
        var waited: u32 = 0;
        while (true) {
            if (w.stopFile()) |f| {
                w.say("STOP ({s}) while {t} waited for a quiet host", .{ f, step });
                return .stopped;
            }
            const l = loadNow() orelse {
                w.say("-- quiet gate for {t}: the load cannot be read; going on {s}", .{ step, w.when(false) });
                return null;
            };
            if (l < w.opts.load_max) {
                w.say("-- quiet gate for {t} passed {s}: load {d:.2} < {d:.2} (waited {d} s)", .{ step, w.when(false), l, w.opts.load_max, waited });
                return null;
            }
            if (waited >= w.opts.quiet_wait_s) {
                w.say("QUIET GATE FAILED for {t} {s}: load {d:.2} after {d} s - {t} not started", .{ step, w.when(false), l, waited, step });
                return .not_quiet;
            }
            if (waited % 300 == 0) w.say("   (waiting for a quiet host before {t}: load {d:.2}, {s})", .{ step, l, w.when(false) });
            Io.sleep(w.io, .fromSeconds(20), .awake) catch {};
            waited += 20;
        }
    }
};

/// The whole window; its exit status.
pub fn run(gpa: Allocator, arena: Allocator, io: Io, opts: Options, s: suite_mod.Suite, environ: *const std.process.Environ.Map) !Exit {
    const self_exe = try std.process.executablePathAlloc(io, arena);
    var w: Window = .{ .gpa = gpa, .arena = arena, .io = io, .opts = opts, .environ = environ, .self_exe = self_exe };
    const alone = opts.base == null;
    var steps_text: std.ArrayList(u8) = .empty;
    for (opts.steps, 0..) |st, i| {
        if (i > 0) try steps_text.append(arena, ' ');
        try steps_text.appendSlice(arena, @tagName(st));
    }
    w.say("== perf_bench window {s}: tip {s} ({s}){s}{s}{s}, steps {s}, runs {d} + {d} collected, load {s}{s}", .{
        w.when(true),                                              opts.tip,                                            opts.tip_commit,
        if (alone) ", ALONE (no base, no verdict)" else ", base ", opts.base orelse "",                                 if (alone) "" else try std.fmt.allocPrint(arena, " ({s})", .{opts.base_commit orelse "?"}),
        steps_text.items,                                          opts.runs,                                           opts.memory_runs,
        w.loadText(),                                              if (opts.dry_run) " (DRY RUN: checks only)" else "",
    });
    const input = struct {
        fn f(win: *Window, comptime fmt: []const u8, args: anytype) Exit {
            win.say("INPUT CHECK FAILED: " ++ fmt, args);
            return .input;
        }
    }.f;

    if (w.stopFile()) |f| {
        w.say("STOP ({s}) present: not started", .{f});
        return .stopped;
    }
    // The host a pair is timed on (docs/performance.md, "The rules").
    const host = (try std.process.run(arena, io, .{ .argv = &.{ "hostname", "-s" } })).stdout;
    const host_name = std.mem.trim(u8, host, " \t\r\n");
    if (!std.mem.eql(u8, host_name, opts.timing_host)) {
        if (!opts.any_host) return input(&w, "a cost pair is timed on {s}.local only; this is {s} (--any-host: a mechanism run, never a published figure)", .{ opts.timing_host, host_name });
        w.say("check: host {s}, not {s}: --any-host - A MECHANISM RUN, never a published figure", .{ host_name, opts.timing_host });
    }
    if (!std.fs.path.isAbsolute(opts.out)) return input(&w, "--out={s}: name it by its absolute path", .{opts.out});

    // The consoles.
    const tip = switch (try checkConsole(arena, io, opts.tip, opts.tip_commit)) {
        .ok => |c| c,
        .problem => |p| return input(&w, "{s}", .{p}),
    };
    w.say("check: tip {s} OK: {s}", .{ tip.dir, tip.build_info[0..@min(tip.build_info.len, 200)] });
    var base: ?Console = null;
    if (opts.base) |dir| {
        const commit = opts.base_commit orelse return input(&w, "--base needs --base-commit=<sha>", .{});
        base = switch (try checkConsole(arena, io, dir, commit)) {
            .ok => |c| c,
            .problem => |p| return input(&w, "{s}", .{p}),
        };
        w.say("check: base {s} OK: {s}", .{ base.?.dir, base.?.build_info[0..@min(base.?.build_info.len, 200)] });
        if (std.mem.eql(u8, tip.repl_sha256, base.?.repl_sha256)) return input(&w, "the tip and the base are one binary (sha256 {s}): the pair compares nothing", .{tip.repl_sha256});
        if (sameCommit(tip.commit, base.?.commit)) return input(&w, "the tip and the base are one commit ({s})", .{tip.commit});
        w.say("check: two different repl binaries", .{});
    }
    // The mirror's tree is the tip's: the pages it serves are the tip's.
    if (opts.tree_head) |path| {
        const head = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(4096)) catch |err| return input(&w, "--tree-head={s}: {t}", .{ path, err });
        if (try treeHeadProblem(arena, head, opts.tip_commit, opts.tree_differs)) |p| return input(&w, "{s}", .{p});
        if (sameCommit(head, opts.tip_commit)) {
            w.say("check: the mirror's tree.head {s} is the tip", .{std.mem.trim(u8, head, " \t\r\n")});
        } else w.say("check: the mirror's tree.head {s} is NOT the tip {s}, measured anyway: {s}", .{ std.mem.trim(u8, head, " \t\r\n"), opts.tip_commit, opts.tree_differs.? });
    } else if (opts.tree_differs != null) return input(&w, "--tree-differs needs --tree-head=<file>", .{});
    const workloads = try selectedWorkloads(arena, s, opts.only);
    if (workloads.len == 0) return input(&w, "--only={s} selects no page of {s}", .{ opts.only orelse "", opts.suite_path });
    w.say("check: suite {s}: {d} workloads selected{s}{s}", .{ opts.suite_path, workloads.len, if (opts.only != null) " by --only=" else "", opts.only orelse "" });

    // A fresh OUT every window: an earlier run's records would be read as
    // this one's.
    if (Io.Dir.cwd().access(io, opts.out, .{})) |_| {
        if (!opts.move_aside) return input(&w, "{s} exists: an earlier run's records would be read as this window's - give it a fresh --out, or --out-exists=move-aside", .{opts.out});
        var sb: [32]u8 = undefined;
        const aside = try std.fmt.allocPrint(arena, "{s}.moved-{s}", .{ opts.out, utcStamp(&sb, w.nowS()) });
        try Io.Dir.cwd().rename(opts.out, Io.Dir.cwd(), aside, io);
        w.say("check: {s} existed: moved aside to {s}", .{ opts.out, aside });
    } else |_| {}
    try Io.Dir.cwd().createDirPath(io, opts.out);
    var keep_out = !opts.dry_run;
    defer if (!keep_out) Io.Dir.cwd().deleteTree(io, opts.out) catch {};
    const log_path = try std.fs.path.join(arena, &.{ opts.out, "window.log" });
    w.log = try Io.Dir.cwd().createFile(io, log_path, .{ .exclusive = true });
    defer if (w.log) |f| f.close(io);

    // The pins, and what the window is.
    const pins_dir = try std.fs.path.join(arena, &.{ opts.out, "pins" });
    try Io.Dir.cwd().createDirPath(io, pins_dir);
    var ub: [32]u8 = undefined;
    const installed = try arena.dupe(u8, utcStamp(&ub, w.nowS()));
    var pin_args: std.ArrayList([]const u8) = .empty;
    var sides: std.ArrayList(engines.Name) = .empty;
    for ([_]struct { engines.Name, ?Console }{ .{ .crane, tip }, .{ .crane_base, base } }) |side| {
        const c = side[1] orelse continue;
        const path = try std.fs.path.join(arena, &.{ pins_dir, try std.fmt.allocPrint(arena, "{t}.pin", .{side[0]}) });
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = try pinText(arena, side[0], c, installed) });
        try pin_args.append(arena, try std.fmt.allocPrint(arena, "--pin={s}", .{path}));
        try sides.append(arena, side[0]);
    }
    {
        var text: Io.Writer.Allocating = .init(arena);
        try text.writer.print("tip={s} {s}\nbase={s} {s}\nsteps={s}\nruns={d}\nmemory_runs={d}\nround={d}\nsuite={s}\nonly={s}\ntree_head={s}\ntree_differs={s}\nhost={s}\n", .{
            tip.dir, tip.commit, if (base) |b| b.dir else "(alone)", if (base) |b| b.commit else "", steps_text.items, opts.runs, opts.memory_runs, opts.round, opts.suite_path, opts.only orelse "", opts.tree_head orelse "", opts.tree_differs orelse "", host_name,
        });
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ opts.out, "WINDOW" }), .data = text.written() });
    }

    // perf_bench check: the pins, and one page launched in each console.
    {
        var args: std.ArrayList([]const u8) = .empty;
        try args.appendSlice(arena, &.{ "check", try std.fmt.allocPrint(arena, "--suite={s}", .{opts.suite_path}), try std.fmt.allocPrint(arena, "--root={s}", .{opts.root}), try std.fmt.allocPrint(arena, "--check-timeout-s={d}", .{opts.check_timeout_s}) });
        try args.appendSlice(arena, pin_args.items);
        for (opts.stop_files) |f| try args.append(arena, try std.fmt.allocPrint(arena, "--stop-file={s}", .{f}));
        const rc = try w.child(args.items, try std.fs.path.join(arena, &.{ opts.out, "check.log" }), null, true);
        if (rc == 3) {
            w.say("STOP during perf_bench check: not started", .{});
            return .stopped;
        }
        if (rc != 0) return input(&w, "perf_bench check exited {d} (its output above)", .{rc});
    }
    if (opts.dry_run) {
        w.say("== checks passed {s} (DRY RUN: nothing measured, {s} removed)", .{ w.when(false), opts.out });
        return .within;
    }
    keep_out = true;

    w.say("WINDOW START {s}: tip {s} ({s}), base {s}{s}; out {s}{s}{s}", .{
        w.when(true), tip.dir, tip.commit, if (base) |b| b.dir else "(alone)", if (base) |b| try std.fmt.allocPrint(arena, " ({s})", .{b.commit}) else "", opts.out, if (opts.tree_differs != null) "; tree differs: " else "", opts.tree_differs orelse "",
    });
    const ended = struct {
        fn f(win: *Window, out: []const u8, code: Exit) Exit {
            win.say("WINDOW END {s} -> {s}: exit {d} ({t})", .{ win.when(true), out, @backingInt(code), code });
            return code;
        }
    }.f;
    var have_default = false;
    var have_memory = false;
    for (opts.steps) |step| {
        if (w.stopFile()) |f| {
            w.say("STOP ({s}) before {t}", .{ f, step });
            return ended(&w, opts.out, .stopped);
        }
        switch (step) {
            .D, .M => {
                if (w.quietGate(step)) |code| return ended(&w, opts.out, code);
                const memory = step == .M;
                const runs = if (memory) opts.memory_runs else opts.runs;
                const pass_dir = try std.fs.path.join(arena, &.{ opts.out, if (memory) "memory" else "default" });
                var args: std.ArrayList([]const u8) = .empty;
                try args.appendSlice(arena, &.{
                    "run",
                    try std.fmt.allocPrint(arena, "--suite={s}", .{opts.suite_path}),
                    try std.fmt.allocPrint(arena, "--root={s}", .{opts.root}),
                    try std.fmt.allocPrint(arena, "--out={s}", .{pass_dir}),
                    try std.fmt.allocPrint(arena, "--round={d}", .{opts.round}),
                    try std.fmt.allocPrint(arena, "--runs={d}", .{runs}),
                    try std.fmt.allocPrint(arena, "--max-timeouts={d}", .{opts.max_timeouts}),
                });
                try args.appendSlice(arena, pin_args.items);
                if (opts.only) |o| try args.append(arena, try std.fmt.allocPrint(arena, "--only={s}", .{o}));
                for (opts.stop_files) |f| try args.append(arena, try std.fmt.allocPrint(arena, "--stop-file={s}", .{f}));
                var env: ?std.process.Environ.Map = null;
                if (memory) {
                    try args.append(arena, "--collected");
                    // The memory pass: the allocator's deferred-reclamation
                    // ring off and one malloc magazine, on every side
                    // (AGENTS.md, "The 3% memory bar reads what Crane holds").
                    var m = try environ.clone(arena);
                    try m.put("MallocLargeCache", "0");
                    try m.put("MallocMaxMagazines", "1");
                    env = m;
                }
                w.say("-- {t} {s} pass START {s}: {d} runs x {d} workloads x {d} consoles{s}, load {s}", .{ step, if (memory) "memory" else "default", w.when(false), runs, workloads.len, sides.items.len, if (memory) ", MallocLargeCache=0 MallocMaxMagazines=1 on every side, --collected" else "", w.loadText() });
                const pass_log = try std.fmt.allocPrint(arena, "{s}.log", .{pass_dir});
                const rc = try w.child(args.items, pass_log, if (env) |*m| m else null, false);
                // Its records, counted before anything reads them.
                const jpath = try std.fs.path.join(arena, &.{ pass_dir, "journal.jsonl" });
                const bytes = Io.Dir.cwd().readFileAlloc(io, jpath, arena, .limited(1 << 30)) catch "";
                var failure: journal.Failure = .{};
                const records = journal.parseJournal(arena, bytes, &failure) catch |err| {
                    w.say("-- {t} END {s} rc={d}: {s}:{d}: {t} - the journal is unreadable", .{ step, w.when(false), rc, jpath, failure.line, err });
                    return ended(&w, opts.out, .incomplete);
                };
                const count = try countRecords(arena, records, workloads, runs, sides.items);
                var line: Io.Writer.Allocating = .init(arena);
                try writeCount(&line.writer, count, runs, workloads.len, sides.items.len);
                w.say("-- {t} END {s} rc={d}: {s}, load {s}", .{ step, w.when(false), rc, line.written(), w.loadText() });
                if (rc != 0) {
                    // perf_bench run's own last word (its STOPPED line).
                    const log_text = Io.Dir.cwd().readFileAlloc(io, pass_log, arena, .limited(64 << 20)) catch "";
                    var last: []const u8 = "";
                    var it = std.mem.splitScalar(u8, log_text, '\n');
                    while (it.next()) |l| if (std.mem.indexOf(u8, l, "STOPPED") != null or (std.mem.startsWith(u8, l, "perf_bench: ") and std.mem.indexOf(u8, l, "error") != null)) {
                        last = l;
                    };
                    w.say("   {t} did not finish: perf_bench run exited {d}{s}{s} ({s})", .{ step, rc, if (last.len > 0) ": " else "", last, pass_log });
                    return ended(&w, opts.out, if (rc == 3) .stopped else .incomplete);
                }
                if (!count.complete()) {
                    w.say("   {t} is not the whole pass: NO VERDICT is read from it", .{step});
                    return ended(&w, opts.out, .incomplete);
                }
                if (memory) {
                    var collected: u32 = 0;
                    for (records) |r| if (r.memory) |m| if (m.footprint_collected != null) {
                        collected += 1;
                    };
                    w.say("   records with a collected figure: {d}", .{collected});
                    have_memory = true;
                } else have_default = true;
            },
            .C => {
                if (alone) {
                    w.say("== C: ALONE - one console, no pair: no verdict (the journals are in {s})", .{opts.out});
                    continue;
                }
                if (!have_default) {
                    w.say("== C: no complete default pass in this window: no verdict", .{});
                    return ended(&w, opts.out, .incomplete);
                }
                w.say("==== THE VERDICT {s}: perf_bench cost, the tip (crane) against the base (crane_base){s}", .{ w.when(false), if (have_memory) "" else " - NO MEMORY PASS: memory not judged" });
                var args: std.ArrayList([]const u8) = .empty;
                try args.appendSlice(arena, &.{ "cost", try std.fmt.allocPrint(arena, "--default={s}/default", .{opts.out}) });
                if (have_memory) try args.append(arena, try std.fmt.allocPrint(arena, "--memory={s}/memory", .{opts.out}));
                const rc = try w.child(args.items, try std.fs.path.join(arena, &.{ opts.out, "cost-tip-vs-base.txt" }), null, true);
                w.say("==== cost exit status {d} (1 = a row is over the bar and not cleared; the VERDICT line above is the pair's)", .{rc});
                switch (rc) {
                    0 => {},
                    1 => return ended(&w, opts.out, .over),
                    else => return ended(&w, opts.out, .incomplete),
                }
            },
        }
    }
    return ended(&w, opts.out, .within);
}

// ---------------------------------------------------------------------------

const testing = std.testing;

test "the clock reads US Eastern, 12-hour, across both daylight-time changes" {
    var buf: [48]u8 = undefined;
    // 2026-11-25 03:06 UTC: 10:06 PM EST on the 24th.
    const t = daysFromCivil(2026, 11, 25) * 86400 + 3 * 3600 + 6 * 60;
    try testing.expectEqualStrings("10:06 PM ET", easternTime(&buf, t, false));
    try testing.expectEqualStrings("10:06 PM ET 2026-11-24", easternTime(&buf, t, true));
    // Summer: 2026-07-04 16:00 UTC is noon EDT.
    try testing.expectEqualStrings("12:00 PM ET", easternTime(&buf, daysFromCivil(2026, 7, 4) * 86400 + 16 * 3600, false));
    // Midnight is 12 AM: 2026-01-15 05:30 UTC.
    try testing.expectEqualStrings("12:30 AM ET", easternTime(&buf, daysFromCivil(2026, 1, 15) * 86400 + 5 * 3600 + 30 * 60, false));
    // Spring forward, 2026-03-08 (the second Sunday): 1:59 AM EST, then 3:00 AM EDT.
    const spring = daysFromCivil(2026, 3, 8) * 86400 + 7 * 3600;
    try testing.expectEqualStrings("1:59 AM ET", easternTime(&buf, spring - 60, false));
    try testing.expectEqualStrings("3:00 AM ET", easternTime(&buf, spring, false));
    // Fall back, 2026-11-01 (the first Sunday): 1:59 AM EDT, then 1:00 AM EST.
    const fall = daysFromCivil(2026, 11, 1) * 86400 + 6 * 3600;
    try testing.expectEqualStrings("1:59 AM ET", easternTime(&buf, fall - 60, false));
    try testing.expectEqualStrings("1:00 AM ET", easternTime(&buf, fall, false));
    try testing.expectEqual(@as(i64, -4), easternOffsetHours(fall - 1));
    try testing.expectEqual(@as(i64, -5), easternOffsetHours(fall));
    // Another year's rule days: 2027-03-14 and 2027-11-07.
    try testing.expectEqual(@as(u32, 14), nthSunday(2027, 3, 2));
    try testing.expectEqual(@as(u32, 7), nthSunday(2027, 11, 1));
    try testing.expectEqual(@as(i64, 0), daysFromCivil(1970, 1, 1));
    try testing.expectEqualStrings("20261125T030600Z", utcStamp(&buf, t));
}

test "commits: abbreviations of one commit match, BUILD_INFO names its tree's commit" {
    try testing.expect(sameCommit("635d7dfd6", "635d7dfd6a1b2c"));
    try testing.expect(sameCommit("635d7dfd6\n", " 635d7dfd6"));
    try testing.expect(!sameCommit("635d7dfd6", "635d7dfd7"));
    try testing.expect(!sameCommit("635d7d", "635d7dfd6"));
    try testing.expect(!sameCommit("main", "main"));
    const info = "host=chat built on chat 2026-11-24 22:41:00 UTC zig=0.17.1-dev+77c319a0f0 v8=15.7.112.43 tree=lane/hard1-b e87fbe638, round 10's sequence";
    try testing.expect(mentionsCommit(info, "e87fbe638"));
    try testing.expect(mentionsCommit(info, "e87fbe6380abcdef"));
    try testing.expect(!mentionsCommit(info, "8d44f5f90"));
    // A run of hex digits inside a word is not a sha.
    try testing.expect(!mentionsCommit("xe87fbe638", "e87fbe638"));
    try testing.expectEqualStrings("15.7.112.43", v8Of(info).?);
    try testing.expectEqual(@as(?[]const u8, null), v8Of("tree=main 8d44f5f90"));
}

test "a console's modes: the ReleaseSafe release build for apple_m1 and nothing else" {
    const safe = "optimize=root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap, libc malloc";
    try testing.expectEqual(@as(?[]const u8, null), modesProblem(safe ++ "\ntarget_cpu=apple_m1-fuse_aes\n"));
    try testing.expectEqual(@as(?[]const u8, null), modesProblem(safe ++ "\ntarget_cpu=apple_m1\n"));
    try testing.expect(modesProblem(safe ++ "\ntarget_cpu=apple_m4-fuse_aes (native)\n") != null);
    try testing.expect(modesProblem(safe ++ "\ntarget_cpu=apple_m1-fuse_aes (native)\n") != null);
    try testing.expect(modesProblem("optimize=root ReleaseFast, Crane modules ReleaseFast, C libraries ReleaseFast, sanitize_c off, libc malloc\ntarget_cpu=apple_m1\n") != null);
    try testing.expect(modesProblem(safe ++ "\n") != null);
    try testing.expect(modesProblem(safe ++ "\ntarget_cpu=apple_m1\nextra=1\n") != null);
}

test "SHA256SUMS lines, as shasum writes them" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sha = "abababababababababababababababababababababababababababababababab";
    const sums = try parseSums(a, sha ++ "  repl\n" ++ sha ++ " *whatwg_snapshot.bin\n\n");
    try testing.expectEqual(@as(usize, 2), sums.len);
    try testing.expectEqualStrings("repl", sums[0].file);
    try testing.expectEqualStrings("whatwg_snapshot.bin", sums[1].file);
    try testing.expectError(error.BadSumsLine, parseSums(a, "nothex  repl\n"));
    try testing.expectError(error.BadSumsLine, parseSums(a, sha ++ "  ../repl\n"));
}

test "a console dir: its sums, its modes and its BUILD_INFO are checked, and the first fault is named" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const safe = "optimize=root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap, libc malloc\ntarget_cpu=apple_m1-fuse_aes\n";
    try tmp.dir.writeFile(io, .{ .sub_path = "repl", .data = "\x7fELF...V8 15.7.112.43..." });
    try tmp.dir.writeFile(io, .{ .sub_path = "repl.modes", .data = safe });
    try tmp.dir.writeFile(io, .{ .sub_path = "whatwg_snapshot.bin", .data = "snapshot" });
    try tmp.dir.writeFile(io, .{ .sub_path = "BUILD_INFO", .data = "host=chat zig=0.17.1 v8=15.7.112.43 tree=lane/tool1 635d7dfd6\n" });
    const dir = try tmp.dir.realPathFileAlloc(io, ".", a);
    var sums: Io.Writer.Allocating = .init(a);
    for (console_files) |f| {
        var hex: [64]u8 = undefined;
        try engines.sha256File(io, try std.fs.path.join(a, &.{ dir, f }), &hex);
        try sums.writer.print("{s}  {s}\n", .{ &hex, f });
    }
    try tmp.dir.writeFile(io, .{ .sub_path = "SHA256SUMS", .data = sums.written() });

    const ok = (try checkConsole(a, io, dir, "635d7dfd6")).ok;
    try testing.expectEqualStrings("15.7.112.43", ok.v8);
    try testing.expectEqualStrings("apple_m1-fuse_aes", ok.target_cpu);
    try testing.expectEqualStrings("root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap, libc malloc", ok.optimize);
    // The pin it makes is one perf_bench reads as a Crane release build.
    const pin = try engines.parsePin(a, try pinText(a, .crane, ok, "20261124T220000Z"));
    try testing.expectEqualStrings("635d7dfd6", pin.commit.?);
    try testing.expectEqualStrings(ok.repl_sha256, pin.sha256);

    // Another commit's console.
    try testing.expect(std.mem.indexOf(u8, (try checkConsole(a, io, dir, "8d44f5f90")).problem, "does not name commit 8d44f5f90") != null);
    // A relative path.
    try testing.expect(std.mem.indexOf(u8, (try checkConsole(a, io, "rel/dir", "635d7dfd6")).problem, "absolute path") != null);
    // A file changed after it was frozen.
    try tmp.dir.writeFile(io, .{ .sub_path = "whatwg_snapshot.bin", .data = "another snapshot" });
    try testing.expect(std.mem.indexOf(u8, (try checkConsole(a, io, dir, "635d7dfd6")).problem, "does not match its SHA256SUMS") != null);
    // Sums that leave out the snapshot.
    try tmp.dir.writeFile(io, .{ .sub_path = "SHA256SUMS", .data = sums.written()[0 .. 2 * (64 + 2) + "repl".len + "repl.modes".len + 2] });
    try testing.expect(std.mem.indexOf(u8, (try checkConsole(a, io, dir, "635d7dfd6")).problem, "does not cover whatwg_snapshot.bin") != null);
}

test "a file holds a string across the reader's pieces" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const big = try testing.allocator.alloc(u8, 600 * 1024);
    defer testing.allocator.free(big);
    @memset(big, 'x');
    // Across the first piece's end (256 KiB).
    @memcpy(big[256 * 1024 - 3 ..][0..11], "15.7.112.43");
    try tmp.dir.writeFile(io, .{ .sub_path = "f", .data = big });
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const path = try tmp.dir.realPathFileAlloc(io, "f", arena.allocator());
    try testing.expect(try fileContains(testing.allocator, io, path, "15.7.112.43"));
    try testing.expect(!try fileContains(testing.allocator, io, path, "13.1.203"));
}

test "the mirror's tree.head: the tip's commit, or measured only with a reason" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqual(@as(?[]const u8, null), try treeHeadProblem(a, "635d7dfd6\n", "635d7dfd6", null));
    const p = (try treeHeadProblem(a, "a2dcf460d\n", "635d7dfd6", null)).?;
    try testing.expect(std.mem.indexOf(u8, p, "a2dcf460d") != null and std.mem.indexOf(u8, p, "--tree-differs") != null);
    try testing.expectEqual(@as(?[]const u8, null), try treeHeadProblem(a, "a2dcf460d", "635d7dfd6", "the mirror synced tool1's tree after cs1's consoles were frozen; tests/perf is unchanged between them"));
    // An empty reason is no reason.
    try testing.expect((try treeHeadProblem(a, "a2dcf460d", "635d7dfd6", "  ")) != null);
}

test "steps" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualSlices(Step, &.{ .D, .M, .C }, try parseSteps(a, "D,M,C"));
    try testing.expectEqualSlices(Step, &.{ .M, .C }, try parseSteps(a, "M C"));
    try testing.expectError(error.UnknownStep, parseSteps(a, "D,X"));
    try testing.expectError(error.NoSteps, parseSteps(a, ","));
}

fn countRecord(name: engines.Name, workload: []const u8, run_index: u32, status: journal.Status) journal.Record {
    return .{
        .format = journal.format_name,
        .round = 10,
        .time = "2026-11-24T22:00:00Z",
        .host = .{ .name = "chat", .os = "macOS", .arch = "aarch64", .cpu = "M4 Pro", .cores = 14, .memory_bytes = 1 },
        .engine = .{ .name = name, .version = "v", .build = "release", .binary = "/b/repl", .binary_sha256 = "abababababababababababababababababababababababababababababababab", .flags = &.{} },
        .page = "workloads/observers.html",
        .workload = workload,
        .kind = .timed,
        .run = run_index,
        .status = status,
    };
}

test "a pass's records against runs x workloads x consoles: hard1's re-queued window, a timed-out launch, another window's records" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const workloads = [_][]const u8{ "observers.mutation-construct", "observers.resize-construct" };
    const sides = [_]engines.Name{ .crane, .crane_base };
    var records: std.ArrayList(journal.Record) = .empty;
    for (0..3) |r| for (sides) |s| {
        for (workloads) |wl| try records.append(a, countRecord(s, wl, @intCast(r), .ok));
        // The page's own row is not counted (a timed-out launch has none).
        try records.append(a, countRecord(s, "page.observers", @intCast(r), .ok));
    };
    const whole = try countRecords(a, records.items, &workloads, 3, &sides);
    try testing.expect(whole.complete());
    try testing.expectEqual(@as(u32, 12), whole.expected);
    var line: Io.Writer.Allocating = .init(a);
    try writeCount(&line.writer, whole, 3, workloads.len, sides.len);
    try testing.expectEqualStrings("12 of 12 records (3 runs x 2 workloads x 2 consoles), 0 not ok", line.written());

    // hard1, 2026-11-24: a cancelled run's records, 1-2 launches a console
    // of 7, read as a whole pass.
    const short = try countRecords(a, records.items[0..8], &workloads, 7, &sides);
    try testing.expect(!short.complete());
    try testing.expectEqual(@as(u32, 28), short.expected);
    try testing.expectEqual(@as(u32, 6), short.found);
    var line2: Io.Writer.Allocating = .init(a);
    try writeCount(&line2.writer, short, 7, workloads.len, sides.len);
    try testing.expectEqualStrings("6 of 28 records (7 runs x 2 workloads x 2 consoles), 0 not ok - INCOMPLETE: 22 missing (the first: crane observers.mutation-construct run 2)", line2.written());

    // A launch that timed out still writes its workloads' records: whole,
    // with its not-ok count.
    records.items[0].status = .timeout;
    const timed_out = try countRecords(a, records.items, &workloads, 3, &sides);
    try testing.expect(timed_out.complete());
    try testing.expectEqual(@as(u32, 1), timed_out.not_ok);

    // Records of an engine or a run this window did not pin: another
    // window's journal.
    try records.append(a, countRecord(.chrome, workloads[0], 0, .ok));
    try records.append(a, countRecord(.crane, workloads[0], 5, .ok));
    const foreign = try countRecords(a, records.items, &workloads, 3, &sides);
    try testing.expect(!foreign.complete());
    try testing.expectEqual(@as(u32, 2), foreign.foreign);
    // A record twice.
    _ = records.pop();
    _ = records.pop();
    try records.append(a, countRecord(.crane, workloads[1], 2, .ok));
    const twice = try countRecords(a, records.items, &workloads, 3, &sides);
    try testing.expect(!twice.complete());
    try testing.expectEqual(@as(u32, 1), twice.duplicate);
}

test "the selected workloads: --only selects whole pages" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const s: suite_mod.Suite = .{ .format = "crane-perf-suite/1", .pages = &.{
        .{ .page = "workloads/overhead.html", .kind = .timed, .workloads = &.{"overhead.empty"} },
        .{ .page = "workloads/observers.html", .kind = .timed, .workloads = &.{ "observers.mutation-construct", "observers.resize-construct" } },
    } };
    try testing.expectEqual(@as(usize, 3), (try selectedWorkloads(a, s, null)).len);
    const only = try selectedWorkloads(a, s, "resize");
    try testing.expectEqual(@as(usize, 2), only.len);
    try testing.expectEqualStrings("observers.mutation-construct", only[0]);
    try testing.expectEqual(@as(usize, 0), (try selectedWorkloads(a, s, "nothing")).len);
}
