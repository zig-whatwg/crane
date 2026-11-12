//! `fw_matrix run`: each suite's pages in Crane's console, the result read
//! from the framework's own report, one journal record per test and per
//! page (tmp/plans/framework-matrix-plan.md, section 2.1).
//!
//! Per suite: a static server over its fetched tree (server.zig), then per
//! page a FRESH console - `repl <url> --timeout=<ms>` - given three lines of
//! input: the reader's wait, its read and `.exit` (readers.zig). The console
//! IS the browser (tools/repl.zig): the page is opened the way a user opens
//! it and read the way a user reads it in DevTools; nothing is injected and
//! no upstream file is edited. The exclusion list becomes the framework's
//! own URL filter (exclusions.zig), so excluded tests never run, and each is
//! journaled as NOTRUN with its kind and reason. At most `parallel` consoles
//! at once (perf_bench's shape: a process per page, its own process group,
//! stdin closed then SIGTERM then SIGKILL to end it).
//!
//! A page's outcome:
//!   OK       the framework's final summary was read and its own counts
//!            agree with the per-test list;
//!   TIMEOUT  the wait ended on the page's budget or a stall: the tests
//!            reported so far are kept, the rest of the page's due tests are
//!            TIMEOUT records;
//!   CRASH    the console ended abnormally: its due tests unreported are
//!            CRASH records (none when nothing could be read);
//!   ERROR    no report, the counts disagree, or an exclusion names a test
//!            the page does not define (an upstream rename: the run fails).

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const manifest = @import("manifest.zig");
const exclusions = @import("exclusions.zig");
const readers = @import("readers.zig");
const journal = @import("journal.zig");
const server_mod = @import("server.zig");
const fetch = @import("fetch.zig");

pub const Config = struct {
    suites: []const manifest.Suite,
    frameworks_dir: []const u8,
    excluded_dir: []const u8,
    console: []const u8,
    console_sha256: []const u8,
    crane_commit: []const u8,
    label: []const u8,
    generation: ?u32 = null,
    out_dir: []const u8,
    /// Only these page ids (all when null).
    pages: ?[]const []const u8 = null,
    /// The diagnosis run: no exclusion filter (the list is still checked).
    no_exclusions: bool = false,
    parallel: u32 = 2,
    stop_file: ?[]const u8 = null,
};

pub const Totals = struct {
    counts: journal.Counts = .{},
    pages: u32 = 0,
    pages_ok: u32 = 0,
    missing_exclusions: u32 = 0,
    stopped: bool = false,
};

const Shared = struct {
    gpa: Allocator,
    io: Io,
    config: *const Config,
    suite: manifest.Suite,
    entries: []const exclusions.Entry,
    port: u16,
    journal_file: Io.File,
    mutex: Io.Mutex = .init,
    next: std.atomic.Value(usize) = .init(0),
    pages: []const manifest.Page,
    totals: *Totals,
};

pub fn run(gpa: Allocator, io: Io, config: Config) !Totals {
    try Io.Dir.cwd().createDirPath(io, config.out_dir);
    const console_dir = try std.fmt.allocPrint(gpa, "{s}/console", .{config.out_dir});
    defer gpa.free(console_dir);
    try Io.Dir.cwd().createDirPath(io, console_dir);
    const journal_path = try std.fmt.allocPrint(gpa, "{s}/journal.jsonl", .{config.out_dir});
    defer gpa.free(journal_path);
    // A journal is one run's: a second run writes elsewhere, never into it.
    const journal_file = Io.Dir.cwd().createFile(io, journal_path, .{ .exclusive = true }) catch |err| {
        std.debug.print("fw_matrix: {s}: {t} (each run writes a journal of its own: pass a new --out)\n", .{ journal_path, err });
        return err;
    };
    defer journal_file.close(io);

    var totals: Totals = .{};
    for (config.suites) |suite| {
        if (totals.stopped) break;
        try runSuite(gpa, io, &config, suite, journal_file, &totals);
    }
    return totals;
}

fn stopRequested(io: Io, config: *const Config) bool {
    const f = config.stop_file orelse return false;
    Io.Dir.cwd().access(io, f, .{}) catch return false;
    return true;
}

fn runSuite(gpa: Allocator, io: Io, config: *const Config, suite: manifest.Suite, journal_file: Io.File, totals: *Totals) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Ruling R6: a page that loads resources live from another origin runs
    // only when the manifest allows it.
    if (suite.remote.len > 0 and !suite.allow_live_loads) {
        std.debug.print("fw_matrix: {s}: its page loads {d} resource(s) from another origin and allow_live_loads is false\n", .{ suite.id, suite.remote.len });
        return error.LiveLoadsNotAllowed;
    }
    const tree = try std.fmt.allocPrint(arena, "{s}/{s}", .{ config.frameworks_dir, try manifest.treeName(arena, suite) });
    const stamp = try std.fmt.allocPrint(arena, "{s}/{s}", .{ tree, fetch.stamp_name });
    const have = Io.Dir.cwd().readFileAlloc(io, stamp, arena, .limited(256)) catch {
        std.debug.print("fw_matrix: {s}: {s} is not fetched (run `fw_matrix fetch` first)\n", .{ suite.id, tree });
        return error.NotFetched;
    };
    const want = try fetch.entryHash(arena, suite);
    if (!std.mem.eql(u8, std.mem.trim(u8, have, " \n"), &want)) {
        std.debug.print("fw_matrix: {s}: {s} was fetched for another manifest entry (run `fw_matrix fetch` again)\n", .{ suite.id, tree });
        return error.StaleFetch;
    }

    const list_path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ config.excluded_dir, suite.excluded });
    const list_text = try Io.Dir.cwd().readFileAlloc(io, list_path, arena, .limited(16 << 20));
    var pf: exclusions.ParseFailure = .{};
    const entries = exclusions.parse(arena, list_text, &pf) catch |err| {
        std.debug.print("{s}:{d}: {t}\n", .{ list_path, pf.line, err });
        return err;
    };
    try checkFileEntries(arena, io, tree, suite, entries, list_path);

    var pages: std.ArrayList(manifest.Page) = .empty;
    for (suite.pages) |p| {
        if (config.pages) |only| {
            var wanted = false;
            for (only) |o| if (std.mem.eql(u8, o, p.id)) {
                wanted = true;
            };
            if (!wanted) continue;
        }
        try pages.append(arena, p);
    }

    const server = try server_mod.Server.start(gpa, io, .{ .root = tree, .overlays = try serverOverlays(arena, suite) });
    defer server.stop();
    std.debug.print("fw_matrix: {s} ({s} {s}): {d} page(s), served from {s} on 127.0.0.1:{d}\n", .{ suite.id, suite.title, suite.version, pages.items.len, tree, server.port() });

    var shared: Shared = .{
        .gpa = gpa,
        .io = io,
        .config = config,
        .suite = suite,
        .entries = entries,
        .port = server.port(),
        .journal_file = journal_file,
        .pages = pages.items,
        .totals = totals,
    };
    const n_workers = @max(1, @min(config.parallel, @as(u32, @intCast(pages.items.len))));
    var threads: [16]std.Thread = undefined;
    const n = @min(n_workers, threads.len);
    for (threads[0..n]) |*t| t.* = try std.Thread.spawn(.{}, worker, .{&shared});
    for (threads[0..n]) |t| t.join();
}

/// The suite's overlays as the server takes them (directories relative to
/// the repository root the tool runs in).
pub fn serverOverlays(arena: Allocator, suite: manifest.Suite) ![]const server_mod.Overlay {
    const out = try arena.alloc(server_mod.Overlay, suite.overlay.len);
    for (suite.overlay, out) |o, *s| s.* = .{ .prefix = o.prefix, .dir = o.dir };
    return out;
}

/// Each `[file:<path>]` entry (a file the project runs only through its
/// Node runner) must exist in the tree and be loaded by none of the pages.
fn checkFileEntries(arena: Allocator, io: Io, tree: []const u8, suite: manifest.Suite, entries: []const exclusions.Entry, list_path: []const u8) !void {
    var bad = false;
    for (entries) |e| {
        if (!e.file) continue;
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ tree, e.id });
        Io.Dir.cwd().access(io, path, .{}) catch {
            std.debug.print("{s}:{d}: [file:{s}] is not in the tree: renamed or removed upstream\n", .{ list_path, e.line, e.id });
            bad = true;
            continue;
        };
        for (suite.pages) |p| {
            const page_file = p.path[0 .. std.mem.indexOfScalar(u8, p.path, '?') orelse p.path.len];
            const html = try Io.Dir.cwd().readFileAlloc(io, try std.fmt.allocPrint(arena, "{s}/{s}", .{ tree, page_file }), arena, .limited(16 << 20));
            const base = std.fs.path.basename(e.id);
            if (std.mem.indexOf(u8, html, base) != null) {
                std.debug.print("{s}:{d}: [file:{s}] is loaded by {s}: it runs in the browser page now\n", .{ list_path, e.line, e.id, page_file });
                bad = true;
            }
        }
    }
    if (bad) return error.ExclusionListOutOfDate;
}

fn worker(shared: *Shared) void {
    while (true) {
        const i = shared.next.fetchAdd(1, .acq_rel);
        if (i >= shared.pages.len) return;
        if (stopRequested(shared.io, shared.config)) {
            shared.mutex.lockUncancelable(shared.io);
            defer shared.mutex.unlock(shared.io);
            if (!shared.totals.stopped) std.debug.print("fw_matrix: the stop file is there: no further page starts\n", .{});
            shared.totals.stopped = true;
            return;
        }
        runPage(shared, shared.pages[i]) catch |err| {
            std.debug.print("fw_matrix: {s} {s}: {t}\n", .{ shared.suite.id, shared.pages[i].id, err });
        };
    }
}

/// How the console ended.
const ConsoleEnd = struct {
    term: ?std.process.Child.Term,
    killed: bool,
    /// Ended because the stop file appeared: the page is not recorded.
    stopped: bool = false,
    wall_ms: u64,

    fn text(e: ConsoleEnd, arena: Allocator) ![]const u8 {
        if (e.term) |t| {
            const s = try std.fmt.allocPrint(arena, "{f}", .{t});
            return if (e.killed) std.fmt.allocPrint(arena, "{s} (ended by the harness at its deadline)", .{s}) else s;
        }
        return "unknown";
    }

    fn clean(e: ConsoleEnd) bool {
        const t = e.term orelse return false;
        return !e.killed and t == .exited and t.exited == 0;
    }
};

const Waiter = struct {
    child: std.process.Child,
    io: Io,
    term: ?std.process.Child.Term = null,
    done: std.atomic.Value(bool) = .init(false),

    fn wait(self: *Waiter) void {
        self.term = self.child.wait(self.io) catch null;
        self.done.store(true, .release);
    }

    fn waitFor(self: *Waiter, ms: u64) void {
        var waited: u64 = 0;
        while (!self.done.load(.acquire) and waited < ms) : (waited += 50) Io.sleep(self.io, .fromMilliseconds(50), .awake) catch {};
    }
};

fn signalGroup(pid: i32, sig: std.posix.SIG) void {
    std.posix.kill(-pid, sig) catch {};
    std.posix.kill(pid, sig) catch {};
}

/// One console: `argv`, `input` on its stdin (then closed), its output to
/// the two files; ended by the harness at `deadline_ms`.
fn runConsole(io: Io, argv: []const []const u8, input: []const u8, out_path: []const u8, err_path: []const u8, deadline_ms: u64, stop_file: ?[]const u8) !ConsoleEnd {
    const out_file = try Io.Dir.cwd().createFile(io, out_path, .{});
    defer out_file.close(io);
    const err_file = try Io.Dir.cwd().createFile(io, err_path, .{});
    defer err_file.close(io);
    const t0 = Io.Timestamp.now(io, .awake);
    var w: Waiter = .{ .io = io, .child = try std.process.spawn(io, .{
        .argv = argv,
        .stdin = .pipe,
        .stdout = .{ .file = out_file },
        .stderr = .{ .file = err_file },
        .pgid = 0,
    }) };
    // The pid before the waiter owns the Child (perf_bench runner.zig).
    const pid: i32 = w.child.id.?;
    const stdin = w.child.stdin.?;
    w.child.stdin = null;
    const thread = try std.Thread.spawn(.{}, Waiter.wait, .{&w});
    stdin.writeStreamingAll(io, input) catch {};
    stdin.close(io);
    // Wait in one-second steps, so a stop file (a host's CLOSING NOTICE)
    // ends the console within a second.
    var waited: u64 = 0;
    var stopped = false;
    while (!w.done.load(.acquire) and waited < deadline_ms) : (waited += 1000) {
        w.waitFor(@min(1000, deadline_ms - waited));
        if (stop_file) |f| if (Io.Dir.cwd().access(io, f, .{})) {
            stopped = true;
            break;
        } else |_| {};
    }
    var killed = false;
    if (!w.done.load(.acquire)) {
        killed = true;
        signalGroup(pid, .TERM);
        w.waitFor(5000);
        if (!w.done.load(.acquire)) {
            signalGroup(pid, .KILL);
            w.waitFor(10000);
        }
    }
    thread.join();
    const wall: u64 = @intCast(@max(0, t0.durationTo(Io.Timestamp.now(io, .awake)).toMilliseconds()));
    return .{ .term = w.term, .killed = killed, .stopped = stopped, .wall_ms = wall };
}

/// The tests `defined` that belong to a page: a QUnit module page's module
/// (compared lower-cased, as QUnit's module filter does), else all.
fn definedForPage(arena: Allocator, defined: []const []const u8, module: ?[]const u8) ![]const []const u8 {
    const m = module orelse return defined;
    var out: std.ArrayList([]const u8) = .empty;
    for (defined) |d| {
        const dm = exclusions.qunitModule(d) orelse continue;
        if (std.ascii.eqlIgnoreCase(dm, m)) try out.append(arena, d);
    }
    return out.items;
}

/// The lines of the console's output that report an uncaught exception or
/// an unhandled rejection (the console's printer begins them "Uncaught ").
fn uncaughtLines(arena: Allocator, output: []const u8, into: *std.ArrayList([]const u8)) !void {
    var it = std.mem.splitScalar(u8, output, '\n');
    while (it.next()) |line| {
        if (into.items.len >= journal.max_errors) return;
        // At the line's start, or after the console's "[frame <url>] " /
        // "[worker <url>] " / "[tab n] " mark - never inside the page's
        // own log text.
        const at = std.mem.indexOf(u8, line, "Uncaught ") orelse continue;
        if (at != 0 and !(line[0] == '[' and at >= 2 and line[at - 2] == ']' and line[at - 1] == ' ')) continue;
        try into.append(arena, try arena.dupe(u8, line[at..@min(line.len, at + 500)]));
    }
}

fn runPage(shared: *Shared, page: manifest.Page) !void {
    const gpa = shared.gpa;
    const io = shared.io;
    const config = shared.config;
    const suite = shared.suite;
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // The page's entries: every kind for the existence check, the manifest's
    // skip_kinds for the filter (none in a diagnosis run).
    const all_kinds = [_]exclusions.Kind{ .rendering, .needs_server, .needs_node_build, .node_runner_only };
    const page_entries = try exclusions.forPage(arena, shared.entries, page.module, &all_kinds);
    const applied = if (config.no_exclusions) &[_]exclusions.Entry{} else try exclusions.forPage(arena, shared.entries, page.module, suite.skip_kinds);
    const query = try exclusions.filterQuery(arena, suite.reader, applied);
    const url = try std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/{s}", .{ shared.port, try exclusions.withQuery(arena, page.path, query) });

    const budget_ms: u64 = @as(u64, suite.page_budget_s) * 1000;
    const stall_ms: u64 = @as(u64, suite.page_stall_s) * 1000;
    const input = try readers.consoleInput(arena, suite.reader, budget_ms, stall_ms);
    const timeout_arg = try std.fmt.allocPrint(arena, "--timeout={d}", .{budget_ms + 60_000});
    const out_path = try std.fmt.allocPrint(arena, "{s}/console/{s}-{s}.out", .{ config.out_dir, suite.id, page.id });
    const err_path = try std.fmt.allocPrint(arena, "{s}/console/{s}-{s}.err", .{ config.out_dir, suite.id, page.id });
    const end = try runConsole(io, &.{ config.console, url, timeout_arg }, input, out_path, err_path, budget_ms + 120_000, config.stop_file);
    if (end.stopped) {
        shared.mutex.lockUncancelable(io);
        defer shared.mutex.unlock(io);
        shared.totals.stopped = true;
        std.debug.print("fw_matrix: {s} {s}: ended by the stop file after {d} s; not recorded\n", .{ suite.id, page.id, end.wall_ms / 1000 });
        return;
    }

    const output = Io.Dir.cwd().readFileAlloc(io, out_path, arena, .limited(2 << 30)) catch "";
    const result_json = readers.findResult(output);
    const result: ?readers.PageResult = if (result_json) |j| readers.parse(arena, suite.reader, j) catch null else null;

    var problems: std.ArrayList([]const u8) = .empty;
    var console_errors: std.ArrayList([]const u8) = .empty;
    var records: std.ArrayList(journal.TestRecord) = .empty;
    const base: journal.TestRecord = .{
        .label = config.label,
        .generation = config.generation,
        .crane_commit = config.crane_commit,
        .console_sha256 = config.console_sha256,
        .framework = suite.framework,
        .version = suite.version,
        .suite = suite.id,
        .suite_kind = suite.kind,
        .source_sha256 = suite.source.sha256,
        .page = page.id,
        .module = "",
        .name = "",
        .id = "",
        .status = .PASS,
    };
    var status: journal.PageStatus = .OK;
    var missing_count: u32 = 0;
    if (result) |r| {
        for (r.errors) |e| if (console_errors.items.len < journal.max_errors) try console_errors.append(arena, e);
        // The exclusion list against what the page defines: a rename
        // upstream fails the run instead of excluding nothing.
        const missing = try exclusions.missing(arena, page_entries, r.defined);
        for (missing) |e| {
            try problems.append(arena, try std.fmt.allocPrint(arena, "excluded test not defined by the page (renamed or removed upstream?): [{s}] (list line {d})", .{ e.id, e.line }));
        }
        missing_count = @intCast(missing.len);
        for (try readers.countProblems(arena, suite.reader, r)) |p| try problems.append(arena, p);

        var reported: std.StringHashMapUnmanaged(u32) = .empty;
        for (r.tests) |t| {
            var rec = base;
            rec.module = t.module;
            rec.name = t.name;
            rec.id = t.id;
            rec.status = t.status;
            if (t.project_skip) rec.not_run = .project_skip;
            rec.assertions_passed = t.assertions_passed;
            rec.assertions_total = t.assertions_total;
            rec.message = t.message;
            rec.duration_ms = t.duration_ms;
            try records.append(arena, rec);
            const gop = try reported.getOrPut(arena, t.id);
            gop.value_ptr.* = if (gop.found_existing) gop.value_ptr.* + 1 else 1;
        }
        // Excluded tests: one NOTRUN record each, with the list's reason.
        var excluded_ids: std.StringHashMapUnmanaged(void) = .empty;
        for (applied) |e| {
            try excluded_ids.put(arena, e.id, {});
            if (for (missing) |m| {
                if (std.mem.eql(u8, m.id, e.id)) break true;
            } else false) continue;
            var rec = base;
            rec.module = exclusions.qunitModule(e.id) orelse "";
            rec.name = if (exclusions.qunitModule(e.id)) |m| e.id[m.len + 2 ..] else e.id;
            if (suite.reader == .mocha) {
                rec.module = "";
                rec.name = e.id;
            }
            rec.id = e.id;
            rec.status = .NOTRUN;
            rec.not_run = e.kind.notRun();
            rec.reason = e.why;
            try records.append(arena, rec);
        }
        // Due tests the framework never reported.
        const due = try definedForPage(arena, r.defined, page.module);
        const unreported_status: journal.Status = if (!end.clean()) .CRASH else .TIMEOUT;
        var unreported: u32 = 0;
        for (due) |d| {
            if (excluded_ids.contains(d)) continue;
            if (reported.getPtr(d)) |c| if (c.* > 0) {
                c.* -= 1;
                continue;
            };
            var rec = base;
            if (suite.reader == .qunit) {
                const m = exclusions.qunitModule(d) orelse "";
                rec.module = m;
                rec.name = if (m.len > 0) d[m.len + 2 ..] else d;
            } else rec.name = d;
            rec.id = d;
            rec.status = unreported_status;
            rec.message = if (unreported_status == .CRASH) "the console ended before the framework reported it" else "the page's run did not reach it in its time";
            try records.append(arena, rec);
            unreported += 1;
        }
        if (!end.clean()) {
            status = .CRASH;
        } else if (missing.len > 0) {
            status = .ERROR;
        } else if (!r.finished) {
            status = .TIMEOUT;
        } else if (problems.items.len > 0 or unreported > 0) {
            status = .ERROR;
            if (unreported > 0) try problems.append(arena, try std.fmt.allocPrint(arena, "{d} due test(s) were not reported though the run ended", .{unreported}));
        }
        if (status == .TIMEOUT) try problems.append(arena, try std.fmt.allocPrint(arena, "the framework's run did not end within the page's budget ({d} s) or stalled ({d} s without progress); {d} due test(s) unreported", .{ suite.page_budget_s, suite.page_stall_s, unreported }));
    } else {
        status = if (!end.clean()) .CRASH else .ERROR;
        try problems.append(arena, if (result_json == null) "the console printed no report" else "the report could not be parsed");
    }
    try uncaughtLines(arena, output, &console_errors);

    var loaded: std.ArrayList(journal.Loaded) = .empty;
    if (result) |r| for (r.resources) |u| {
        var sha: ?[]const u8 = null;
        for (suite.remote) |rem| if (std.mem.eql(u8, rem.url, u)) {
            sha = rem.sha256;
        };
        try loaded.append(arena, .{ .url = u, .sha256 = sha });
    };

    var counts: journal.Counts = .{};
    for (records.items) |rec| counts.add(rec);
    const page_record: journal.PageRecord = .{
        .label = config.label,
        .generation = config.generation,
        .crane_commit = config.crane_commit,
        .console_sha256 = config.console_sha256,
        .framework = suite.framework,
        .version = suite.version,
        .suite = suite.id,
        .suite_kind = suite.kind,
        .source_sha256 = suite.source.sha256,
        .page = page.id,
        .url = url,
        .status = status,
        .wall_ms = end.wall_ms,
        .reported_total = if (result) |r| r.reported_total else null,
        .reported_failed = if (result) |r| r.reported_failed else null,
        .ran = counts.ran(),
        .records = @intCast(records.items.len),
        .exit = try end.text(arena),
        .console_errors = console_errors.items,
        .loaded = loaded.items,
        .message = if (problems.items.len > 0) try std.mem.join(arena, "; ", problems.items) else null,
    };

    var buf: Io.Writer.Allocating = .init(arena);
    for (records.items) |rec| try journal.writeTest(&buf.writer, rec);
    try journal.writePage(&buf.writer, page_record);

    shared.mutex.lockUncancelable(io);
    defer shared.mutex.unlock(io);
    try shared.journal_file.writeStreamingAll(io, buf.written());
    shared.totals.counts.merge(counts);
    shared.totals.pages += 1;
    if (status == .OK) shared.totals.pages_ok += 1;
    shared.totals.missing_exclusions += missing_count;
    std.debug.print("fw_matrix: {s} {s}: {t} in {d} s: {d} pass, {d} fail, {d} errored, {d} rendering, {d} not run, {d} skipped by the project{s}{s}\n", .{
        suite.id,                                       page.id,                       status, end.wall_ms / 1000, counts.pass, counts.fail, counts.errored(), counts.rendering, counts.not_run, counts.project_skip,
        if (page_record.message != null) " - " else "", page_record.message orelse "",
    });
}

const testing = std.testing;

test "definedForPage: a module page's tests, compared lower-cased" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const defined = [_][]const u8{ "css: a", "CSS: b", "core: c", "global" };
    try testing.expectEqual(@as(usize, 2), (try definedForPage(arena_state.allocator(), &defined, "css")).len);
    try testing.expectEqual(@as(usize, 4), (try definedForPage(arena_state.allocator(), &defined, null)).len);
}

test "uncaughtLines: the console's uncaught reports, capped" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    var into: std.ArrayList([]const u8) = .empty;
    try uncaughtLines(arena_state.allocator(), "log\nUncaught TypeError: x is not a function\n  at y\n[frame http://a/] Uncaught ReferenceError: z\nsaid Uncaught later\n[x] said Uncaught\n", &into);
    try testing.expectEqual(@as(usize, 2), into.items.len);
    try testing.expectEqualStrings("Uncaught TypeError: x is not a function", into.items[0]);
}

test "a console run: input on stdin, output to its file, its end; a deadline ends a hung one" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(dir);
    const out = try std.fmt.allocPrint(testing.allocator, "{s}/c.out", .{dir});
    defer testing.allocator.free(out);
    const err = try std.fmt.allocPrint(testing.allocator, "{s}/c.err", .{dir});
    defer testing.allocator.free(err);

    const e = try runConsole(testing.io, &.{ "/bin/sh", "-c", "cat; echo bye >&2" }, "CRANE-FW-RESULT {}\n", out, err, 10_000, null);
    try testing.expect(e.clean());
    const got = try tmp.dir.readFileAlloc(testing.io, "c.out", testing.allocator, .limited(100));
    defer testing.allocator.free(got);
    try testing.expectEqualStrings("{}", readers.findResult(got).?);

    const hung = try runConsole(testing.io, &.{ "/bin/sh", "-c", "trap '' TERM; while :; do sleep 0.1; done" }, "", out, err, 300, null);
    try testing.expect(hung.killed);
    try testing.expect(!hung.clean());

    // A stop file ends a console at the next one-second step.
    const stop = try std.fmt.allocPrint(testing.allocator, "{s}/STOP", .{dir});
    defer testing.allocator.free(stop);
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "STOP", .data = "" });
    const stopped = try runConsole(testing.io, &.{ "/bin/sleep", "30" }, "", out, err, 60_000, stop);
    try testing.expect(stopped.stopped);
    try testing.expect(stopped.wall_ms < 20_000);
}
