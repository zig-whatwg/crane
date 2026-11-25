//! The runner: every engine on every page of the suite, `runs` times, in
//! alternating order, each launch a fresh process with a fresh profile;
//! the server answers the pages, the collector turns their marks into
//! records, and every record goes to the journal as its launch ends.
//!
//! Order (the user's rule: alternating pairs): for run r, the engines go in
//! the order given rotated by r, page by page, so no engine always runs
//! first or last, nor always just after the same other engine.
//!
//! A STOP file (`--stop-file`), checked before every launch, ends the run
//! between launches; the window watcher creates it on a CLOSING NOTICE.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const journal = @import("journal.zig");
const suite_mod = @import("suite.zig");
const proc = @import("proc.zig");
const engines = @import("engines.zig");
const server_mod = @import("server.zig");
const collector_mod = @import("collector.zig");
const cdp = @import("cdp.zig");
const webdriver = @import("webdriver.zig");

const Collector = collector_mod.Collector;

pub const Config = struct {
    suite: suite_mod.Suite,
    /// tests/perf, served.
    root: []const u8,
    /// Where journal.jsonl, logs/ and run.txt go (created; must not hold a
    /// journal already).
    out_dir: []const u8,
    /// Fresh profiles are made below it, one per launch, and deleted after.
    profile_root: []const u8,
    round: u32,
    runs: u32,
    pins: []const engines.Pin,
    host: journal.Host,
    environ: *const std.process.Environ.Map,
    /// STOP files (`--stop-file`, repeated): any one present stops the run.
    stop_files: []const []const u8 = &.{},
    /// Only the pages or workloads whose name contains this.
    only: ?[]const u8 = null,
    iterations: u32 = 10,
    warmup: u32 = 3,
    /// How long a page is left alone after each timed workload (and before
    /// its done mark) for the steady footprint (`footprint_settled`).
    settle_ms: u32 = 500,
    sample_ms: u32 = 50,
    /// The server's port (0: any).
    port: u16 = 0,
    /// A memory-only pass of a lane's cost pair (`--collected`): after each
    /// timed workload's settled mark the page asks for a full collection,
    /// stays idle for the settle time again and posts a `collected` mark
    /// (collector.zig). The page then runs at another pace, so such a
    /// pass's times are not a round's, and no published round is run so.
    collected: bool = false,
    /// `--max-timeouts`: the run stops when this many launches of one
    /// engine IN A ROW ended without the page finishing - the time ran out,
    /// or the engine exited first (`FailureGuard`). 0: never.
    max_failed_in_a_row: u32 = 3,
};

/// How one launch ended, as the run's guard reads it.
pub const LaunchEnd = enum {
    /// The page finished (whatever its records say).
    done,
    /// The page's time ran out.
    timeout,
    /// The engine's process ended before the page did.
    crash,
    /// Anything else: the engine could not be driven, the launch was
    /// refused or is unsupported. Neither a failure in a row nor a success.
    other,
    /// A STOP file ended it.
    stopped,

    pub fn of(ending: collector_mod.Ending) LaunchEnd {
        return switch (ending) {
            .done => .done,
            .timeout => .timeout,
            .exited => .crash,
            .driver => .other,
            .stopped => .stopped,
        };
    }
};

/// Launches in a row, per engine, that ended in a timeout or a crash
/// (perf1-guard, 2026-11-24: a release console whose every script threw
/// made perf_bench record "no result in 600 s" on every workload of both
/// sides, and two windows ran 7 h and 5 h before anyone looked). A launch
/// whose page finished starts the count again; any other ending leaves it.
pub const FailureGuard = struct {
    /// 0: the guard never stops a run.
    max: u32,
    in_a_row: std.EnumArray(journal.EngineName, Streak) = .initFill(.{}),

    /// One engine's failed launches since its last finished page.
    pub const Streak = struct {
        timeouts: u32 = 0,
        crashes: u32 = 0,

        pub fn count(s: Streak) u32 {
            return s.timeouts + s.crashes;
        }
    };

    /// Notes one launch of `engine`; its streak when that reached `max`
    /// (the run stops), else null.
    pub fn note(g: *FailureGuard, engine: journal.EngineName, end: LaunchEnd) ?Streak {
        const s = g.in_a_row.getPtr(engine);
        switch (end) {
            .done => s.* = .{},
            .timeout => s.timeouts += 1,
            .crash => s.crashes += 1,
            .other, .stopped => {},
        }
        if (g.max > 0 and s.count() >= g.max) return s.*;
        return null;
    }
};

/// The page `perf_bench check` launches once in every pinned engine
/// (perf1-guard): the suite's own floor, `overhead.empty`, which every
/// engine runs and which needs only the harness's script to post its marks.
/// A console whose every script throws, or that cannot load a page, has no
/// result for it. Its own time limit: a working engine answers in seconds.
pub const check_page: suite_mod.Page = .{ .page = "workloads/overhead.html", .kind = .timed, .timeout_s = 60, .workloads = &.{"overhead.empty"} };

/// What `perf_bench check`'s launches say of each pin: one line per pin
/// with no ok record of the check page's workload (none when every engine
/// answered).
pub fn checkProblems(arena: Allocator, records: []const journal.Record, pins: []const engines.Pin) Allocator.Error![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (pins) |pin| {
        const rec = for (records) |r| {
            if (r.engine.name == pin.name and std.mem.eql(u8, r.workload, check_page.workloads[0])) break r;
        } else {
            try out.append(arena, try std.fmt.allocPrint(arena, "{s}: no record of {s} (the launch made none)", .{ @tagName(pin.name), check_page.workloads[0] }));
            continue;
        };
        if (rec.status == .ok) continue;
        try out.append(arena, try std.fmt.allocPrint(arena, "{s}: {s} on {s}: {s}", .{ @tagName(pin.name), @tagName(rec.status), check_page.page, rec.message orelse "(no message)" }));
    }
    return out.items;
}

/// How a run ended: every launch made, a STOP file, or the guard.
pub const Outcome = union(enum) {
    complete,
    stopped,
    /// `streak` launches of `engine` in a row ended in a timeout or a
    /// crash; the last was `last` (its page, run and ending, as text).
    failing: struct { engine: journal.EngineName, streak: FailureGuard.Streak, last: []const u8 },

    /// The process's exit status for it: 0, 3 (a STOP file: the journal
    /// is not the whole run) or 4 (the guard).
    pub fn exitCode(o: Outcome) u8 {
        return switch (o) {
            .complete => 0,
            .stopped => 3,
            .failing => 4,
        };
    }

    /// The line that says why a run ended early.
    pub fn line(o: Outcome, w: *Io.Writer) Io.Writer.Error!void {
        switch (o) {
            .complete => try w.writeAll("perf_bench: run complete\n"),
            .stopped => try w.writeAll("perf_bench: STOPPED by a STOP file: the journal is not the whole run\n"),
            .failing => |f| try w.print("perf_bench: STOPPED: {d} launches of {s} in a row ended without the page finishing ({d} timed out, {d} crashed); the last: {s}\n", .{ f.streak.count(), @tagName(f.engine), f.streak.timeouts, f.streak.crashes, f.last }),
        }
    }
};

/// The launch in progress, shared with the server's threads (marks) and the
/// sampler: everything below `mutex`.
const Live = struct {
    mutex: Io.Mutex = .init,
    collector: ?*Collector = null,
    token: []const u8 = "",
    selectors: [max_instances]proc.Selector = undefined,
    selector_count: usize = 0,
    started: Io.Timestamp = .zero,
    io: Io,
    /// Set when the sampler should stop.
    sampling: std.atomic.Value(bool) = .init(false),

    fn reading(self: *Live) proc.Reading {
        return self.readingOf(true);
    }

    /// The launched trees alone (no process matched by name): what the
    /// runner may kill at a launch's end - a WebKit process matched by name
    /// could still be another app's.
    fn treeReading(self: *Live) proc.Reading {
        return self.readingOf(false);
    }

    fn readingOf(self: *Live, with_names: bool) proc.Reading {
        // One set, or the sum of an instances row's sets (their pids differ).
        var total: proc.Reading = .{};
        for (self.selectors[0..self.selector_count]) |sel| {
            var s = sel;
            if (!with_names) s.names = &.{};
            const r = proc.Reading.take(s);
            for (r.all()) |u| {
                if (total.count >= proc.max_processes) break;
                total.usages[total.count] = u;
                total.count += 1;
            }
        }
        return total;
    }

    fn sinceStart(self: *Live) f64 {
        const d = self.started.untilNow(self.io, .awake);
        return @as(f64, @floatFromInt(d.nanoseconds)) / 1e6;
    }

    fn onMark(ctx: *anyopaque, body: []const u8) void {
        const self: *Live = @ptrCast(@alignCast(ctx));
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        const c = self.collector orelse return;
        const mark = collector_mod.parseMark(c.arena, body) catch {
            c.log.print(c.arena, "unreadable mark: {s}\n", .{body[0..@min(body.len, 200)]}) catch {};
            return;
        };
        // A mark from another launch (a browser still closing) is not this one's.
        // Each instance's token is "<launch token>.<k>".
        const t = mark.token;
        if (t.len <= self.token.len or !std.mem.startsWith(u8, t, self.token) or t[self.token.len] != '.') return;
        const r = self.reading();
        c.onMark(mark, self.sinceStart(), &r) catch {};
    }

    fn sampler(self: *Live, every_ms: u32) void {
        while (self.sampling.load(.acquire)) {
            Io.sleep(self.io, .fromMilliseconds(every_ms), .awake) catch {};
            self.mutex.lockUncancelable(self.io);
            defer self.mutex.unlock(self.io);
            const c = self.collector orelse continue;
            const r = self.reading();
            c.notePeak(r.footprint());
        }
    }
};

pub const max_instances = 8;

/// One engine process the runner started.
const Process = struct {
    child: std.process.Child,
    pid: i32,
    stdin: ?Io.File = null,
    exited: std.atomic.Value(bool) = .init(false),
    term_text: [64]u8 = undefined,
    term_len: usize = 0,
    waiter: ?std.Thread = null,
    io: Io,

    fn wait(self: *Process) void {
        const term = self.child.wait(self.io) catch {
            self.exited.store(true, .release);
            return;
        };
        const text = std.fmt.bufPrint(&self.term_text, "{f}", .{term}) catch "";
        self.term_len = text.len;
        self.exited.store(true, .release);
    }

    fn termText(self: *const Process) []const u8 {
        return self.term_text[0..self.term_len];
    }

    fn hasExited(self: *const Process) bool {
        return self.exited.load(.acquire);
    }

    /// Ask it to end, then make it: stdin closed (the console ends on end of
    /// input, as Ctrl+D), then SIGTERM to its process group, then SIGKILL.
    fn end(self: *Process) void {
        if (self.stdin) |f| {
            f.close(self.io);
            self.stdin = null;
            self.waitFor(5000);
        }
        if (!self.hasExited()) {
            signalGroup(self.pid, .TERM);
            self.waitFor(5000);
        }
        if (!self.hasExited()) {
            signalGroup(self.pid, .KILL);
            self.waitFor(5000);
        }
        if (self.waiter) |t| t.join();
        self.waiter = null;
    }

    fn waitFor(self: *Process, ms: u32) void {
        var waited: u32 = 0;
        while (!self.hasExited() and waited < ms) : (waited += 20) Io.sleep(self.io, .fromMilliseconds(20), .awake) catch {};
    }
};

fn signalGroup(pid: i32, sig: std.posix.SIG) void {
    std.posix.kill(-pid, sig) catch {};
    std.posix.kill(pid, sig) catch {};
}

/// A port nothing listens on now (bound, read, closed): for the protocol
/// servers Lightpanda and safaridriver start.
fn freePort(io: Io) !u16 {
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(0) };
    var s = try address.listen(io, .{ .reuse_address = true });
    defer s.deinit(io);
    return s.socket.address.getPort();
}

pub const Runner = struct {
    gpa: Allocator,
    io: Io,
    config: Config,
    server: *server_mod.Server = undefined,
    live: Live,
    journal_file: Io.File = undefined,
    journal_buf: [64 * 1024]u8 = undefined,
    journal_writer: Io.File.Writer = undefined,
    out: Io.Dir = undefined,
    launches: u32 = 0,
    records: u32 = 0,
    /// How the last launch ended, as text (`noteEnd`).
    last_end_buf: [256]u8 = undefined,
    last_end_len: usize = 0,

    pub fn init(gpa: Allocator, io: Io, config: Config) Runner {
        return .{ .gpa = gpa, .io = io, .config = config, .live = .{ .io = io } };
    }

    /// Every launch of the run, until a STOP file or the guard
    /// (`max_failed_in_a_row`) ends it; how it ended. The Outcome's text
    /// lives as long as the Runner.
    pub fn run(self: *Runner) !Outcome {
        const cwd = Io.Dir.cwd();
        try cwd.createDirPath(self.io, self.config.out_dir);
        self.out = try cwd.openDir(self.io, self.config.out_dir, .{});
        defer self.out.close(self.io);
        try self.out.createDirPath(self.io, "logs");
        self.journal_file = self.out.createFile(self.io, "journal.jsonl", .{ .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => {
                std.debug.print("perf_bench: {s}/journal.jsonl exists: a run writes a fresh directory\n", .{self.config.out_dir});
                return err;
            },
            else => return err,
        };
        defer self.journal_file.close(self.io);
        self.journal_writer = self.journal_file.writer(self.io, &self.journal_buf);
        try cwd.createDirPath(self.io, self.config.profile_root);

        self.server = try server_mod.Server.start(self.gpa, self.io, .{
            .root = self.config.root,
            .port = self.config.port,
            .sink = .{ .ctx = &self.live, .onMark = Live.onMark },
        });
        defer self.server.stop();
        std.debug.print("perf_bench: serving {s} on http://127.0.0.1:{d}/\n", .{ self.config.root, self.server.port() });

        const pins = self.config.pins;
        var guard: FailureGuard = .{ .max = self.config.max_failed_in_a_row };
        var outcome: Outcome = .complete;
        var r: u32 = 0;
        outer: while (r < self.config.runs) : (r += 1) {
            for (self.config.suite.pages, 0..) |page, pi| {
                if (!self.selected(page)) continue;
                for (0..pins.len) |k| {
                    const pin = pins[(k + r) % pins.len];
                    if (self.stopped()) {
                        outcome = .stopped;
                        break :outer;
                    }
                    const end = try self.launchOne(pin, page, @intCast(pi), r);
                    if (end == .stopped) {
                        outcome = .stopped;
                        break :outer;
                    }
                    if (guard.note(pin.name, end)) |streak| {
                        outcome = .{ .failing = .{ .engine = pin.name, .streak = streak, .last = self.last_end_buf[0..self.last_end_len] } };
                        break :outer;
                    }
                }
            }
        }
        try self.journal_writer.interface.flush();
        std.debug.print("perf_bench: {d} launches, {d} records -> {s}/journal.jsonl\n", .{ self.launches, self.records, self.config.out_dir });
        return outcome;
    }

    fn selected(self: *const Runner, page: suite_mod.Page) bool {
        return pageSelected(page, self.config.only);
    }

    /// "<page> run <r>: <why it ended>" of the last launch, for the
    /// guard's line.
    fn noteEnd(self: *Runner, page: suite_mod.Page, run_index: u32, ending: collector_mod.Ending) void {
        const text = switch (ending) {
            .done => std.fmt.bufPrint(&self.last_end_buf, "{s} run {d}: finished", .{ page.page, run_index }),
            .timeout => |s| std.fmt.bufPrint(&self.last_end_buf, "{s} run {d}: no result in {d} s", .{ page.page, run_index, s }),
            .exited => |e| std.fmt.bufPrint(&self.last_end_buf, "{s} run {d}: the engine exited before the page finished: {s}", .{ page.page, run_index, e }),
            .driver => |e| std.fmt.bufPrint(&self.last_end_buf, "{s} run {d}: the engine could not be driven to the page: {s}", .{ page.page, run_index, e }),
            .stopped => std.fmt.bufPrint(&self.last_end_buf, "{s} run {d}: stopped (STOP file)", .{ page.page, run_index }),
        } catch self.last_end_buf[0..];
        self.last_end_len = text.len;
    }

    fn stopped(self: *const Runner) bool {
        for (self.config.stop_files) |f| {
            Io.Dir.cwd().access(self.io, f, .{}) catch continue;
            std.debug.print("perf_bench: STOP file {s} present: stopping before the next launch\n", .{f});
            return true;
        }
        return false;
    }

    fn nowRfc3339(self: *const Runner, arena: Allocator) ![]const u8 {
        const ts = Io.Clock.real.now(self.io);
        const secs: u64 = @intCast(@divFloor(ts.nanoseconds, std.time.ns_per_s));
        const es: std.time.epoch.EpochSeconds = .{ .secs = secs };
        const yd = es.getEpochDay().calculateYearDay();
        const md = yd.calculateMonthDay();
        const ds = es.getDaySeconds();
        return std.fmt.allocPrint(arena, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
            yd.year, md.month.numeric(), md.day_index + 1, ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
        });
    }

    fn launchOne(self: *Runner, pin: engines.Pin, page: suite_mod.Page, page_index: u32, run_index: u32) !LaunchEnd {
        // Two arenas: the collector's, used only under the live mutex (the
        // server's threads add marks to it), and this thread's own.
        var arena_state: std.heap.ArenaAllocator = .init(self.gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        var collector_arena: std.heap.ArenaAllocator = .init(self.gpa);
        defer collector_arena.deinit();
        self.launches += 1;

        const token = try std.fmt.allocPrint(arena, "{s}.{d}.{d}", .{ @tagName(pin.name), page_index, run_index });
        const time = try self.nowRfc3339(arena);
        const n_instances: u32 = if (page.kind == .instances) @min(page.instances, max_instances) else 1;

        // The flags the journal records are the first instance's.
        var collector: Collector = .{
            .arena = collector_arena.allocator(),
            .base = .{
                .round = self.config.round,
                .time = time,
                .host = self.config.host,
                .engine = .{
                    .name = pin.name,
                    .version = pin.version,
                    .build = pin.build,
                    .commit = pin.commit,
                    .optimize = pin.optimize,
                    .target_cpu = pin.target_cpu,
                    .v8 = pin.v8,
                    .binary = pin.binary,
                    .binary_sha256 = pin.sha256,
                    .flags = &.{},
                },
                .page = page.page,
                .run = run_index,
            },
            .page = page,
        };

        var log_file = try self.out.createFile(self.io, try std.fmt.allocPrint(arena, "logs/{s}.log", .{token}), .{});
        defer log_file.close(self.io);

        if (pin.name == .safari and n_instances > 1) {
            collector.failed.put(collector.arena, page.workloads[0], .{ .message = "safaridriver allows one session at a time: no second instance", .unsupported = true }) catch {};
            try self.writeRecords(try collector.finish(.done));
            return .other;
        }
        // The engine's app must be this launch's own: one already running
        // (a session's left over, or another's) would serve the page with
        // processes started before the launch, outside the set.
        const app_names = engines.appNames(pin.name);
        if (appRunning(app_names)) |pid| {
            const text = try std.fmt.allocPrint(collector.arena, "{s} is already running (pid {d}): its processes would not be this launch's - end it first", .{ app_names[0], pid });
            try self.writeRecords(try collector.finish(.{ .driver = text }));
            std.debug.print("perf_bench: {s} {s} run {d}: refused, {s}\n", .{ @tagName(pin.name), page.page, run_index, text });
            return .other;
        }
        const launch_abs = proc.absoluteNow();

        var processes: [max_instances]Process = undefined;
        var started: usize = 0;
        var series: std.ArrayList(u64) = .empty;
        var ending: collector_mod.Ending = .done;
        var drivers: [max_instances]?Driver = @splat(null);

        // The launch is live from here: marks and samples reach the collector.
        {
            self.live.mutex.lockUncancelable(self.io);
            defer self.live.mutex.unlock(self.io);
            self.live.collector = &collector;
            self.live.token = token;
            self.live.selector_count = 0;
            self.live.started = Io.Timestamp.now(self.io, .awake);
        }
        self.live.sampling.store(true, .release);
        const sampler = try std.Thread.spawn(.{}, Live.sampler, .{ &self.live, self.config.sample_ms });

        defer {
            self.live.sampling.store(false, .release);
            sampler.join();
            // The set as it is before the end, so that what outlives its
            // parent (a helper reparented to launchd) is still found.
            self.live.mutex.lockUncancelable(self.io);
            const before_end = self.live.treeReading();
            self.live.collector = null;
            self.live.selector_count = 0;
            self.live.mutex.unlock(self.io);
            // The protocol sessions first (Safari closes its window), then
            // the processes, then the driver threads (whose reads the ended
            // processes have closed).
            for (&drivers) |*d| if (d.*) |*dr| dr.beginStop();
            for (processes[0..started]) |*p| p.end();
            for (&drivers) |*d| if (d.*) |*dr| dr.join();
            // The app the launch started (Safari stays after Delete Session),
            // by exact pid: started at or after the launch.
            var app_pids: [8]i32 = undefined;
            const n_app = proc.named(app_names, launch_abs, &app_pids);
            if (n_app > 0) {
                const killed = endProcesses(self.io, app_pids[0..n_app], 5000);
                // Its WebKit processes end with it; the next launch's set
                // counts only processes started after that launch.
                var rest: [max_rest]i32 = undefined;
                var waited: u32 = 0;
                while (waited < 5000 and proc.named(engines.setNames(pin.name), launch_abs, &rest) > 0) : (waited += 50) {
                    Io.sleep(self.io, .fromMilliseconds(50), .awake) catch {};
                }
                const left = proc.named(engines.setNames(pin.name), launch_abs, &rest);
                log_file.writeStreamingAll(self.io, std.fmt.allocPrint(arena, "perf_bench: ended {d} app process(es) of the launch ({d} by SIGKILL); {d} of its named processes still running {d} ms after\n", .{ n_app, killed, left, waited }) catch "") catch {};
            }
            for (before_end.all()) |u| if (proc.usageOf(u.pid) != null) {
                std.posix.kill(u.pid, .KILL) catch {};
            };
            for (0..started) |i| {
                const dir = std.fmt.allocPrint(arena, "{s}/{s}.{d}", .{ self.config.profile_root, token, i }) catch continue;
                Io.Dir.cwd().deleteTree(self.io, dir) catch {};
            }
        }

        var k: usize = 0;
        while (k < n_instances) : (k += 1) {
            const inst_token = try std.fmt.allocPrint(arena, "{s}.{d}", .{ token, k });
            const profile = try std.fmt.allocPrint(arena, "{s}/{s}.{d}", .{ self.config.profile_root, token, k });
            try Io.Dir.cwd().createDirPath(self.io, profile);
            if (pin.name == .firefox) {
                var pdir = try Io.Dir.cwd().openDir(self.io, profile, .{});
                defer pdir.close(self.io);
                try pdir.writeFile(self.io, .{ .sub_path = "user.js", .data = engines.firefox_user_js });
            }
            const url = try self.pageUrl(arena, page, inst_token);
            const protocol_port: u16 = switch (engines.driveOf(pin.name)) {
                .argv => 0,
                else => try freePort(self.io),
            };
            const l = try engines.launchWith(arena, pin, url, profile, protocol_port, .{ .collect = page.kind == .retained or (self.config.collected and page.kind == .timed) });
            if (k == 0) collector.base.engine.flags = l.flags;

            var env = try self.config.environ.clone(arena);
            for (l.env) |kv| try env.put(kv[0], kv[1]);

            processes[started] = .{ .child = undefined, .pid = 0, .io = self.io };
            const launched_abs = proc.absoluteNow();
            const p = &processes[started];
            p.child = std.process.spawn(self.io, .{
                .argv = l.argv,
                .environ_map = &env,
                .stdin = if (l.stdin_pipe) .pipe else .ignore,
                .cwd = if (l.cwd) |dir| .{ .path = dir } else .inherit,
                .stdout = .{ .file = log_file },
                .stderr = .{ .file = log_file },
                .pgid = 0,
            }) catch |err| {
                ending = .{ .driver = try std.fmt.allocPrint(arena, "spawn {s}: {t}", .{ l.argv[0], err }) };
                break;
            };
            p.pid = p.child.id.?;
            p.stdin = p.child.stdin;
            p.child.stdin = null;
            started += 1;
            p.waiter = try std.Thread.spawn(.{}, Process.wait, .{p});
            {
                self.live.mutex.lockUncancelable(self.io);
                defer self.live.mutex.unlock(self.io);
                self.live.selectors[self.live.selector_count] = .{ .root = p.pid, .names = l.names, .started_after = launched_abs };
                self.live.selector_count += 1;
            }
            switch (l.drive) {
                .argv => {},
                .cdp, .webdriver => {
                    drivers[k] = .{ .io = self.io, .gpa = self.gpa, .drive = l.drive, .port = protocol_port, .url = url };
                    try drivers[k].?.start();
                },
            }
            if (page.kind == .instances) {
                // Each instance loads and settles before the next starts.
                ending = self.waitFor(&collector, p, &drivers[k], page, .loaded_count, k + 1);
                if (ending != .done) break;
                Io.sleep(self.io, .fromMilliseconds(page.settle_ms), .awake) catch {};
                self.live.mutex.lockUncancelable(self.io);
                const r = self.live.reading();
                self.live.mutex.unlock(self.io);
                try series.append(arena, r.footprint());
            }
        }

        if (started > 0 and ending == .done) switch (page.kind) {
            .timed, .chain, .retained => ending = self.waitFor(&collector, &processes[0], &drivers[0], page, .done, 0),
            .idle => {
                ending = self.waitFor(&collector, &processes[0], &drivers[0], page, .loaded_count, 1);
                if (ending == .done) {
                    Io.sleep(self.io, .fromMilliseconds(page.settle_ms), .awake) catch {};
                    self.live.mutex.lockUncancelable(self.io);
                    defer self.live.mutex.unlock(self.io);
                    const r = self.live.reading();
                    try collector.idle(&r);
                }
            },
            .instances => {
                self.live.mutex.lockUncancelable(self.io);
                defer self.live.mutex.unlock(self.io);
                const r = self.live.reading();
                if (series.items.len >= 2) try collector.instances(series.items, &r);
            },
        };

        // Records are made with the launch still live (the collector is
        // shared), then the engine is ended by the defer above.
        self.live.mutex.lockUncancelable(self.io);
        const records = collector.finish(ending) catch |err| {
            self.live.mutex.unlock(self.io);
            return err;
        };
        if (collector.log.items.len > 0) log_file.writeStreamingAll(self.io, collector.log.items) catch {};
        self.live.mutex.unlock(self.io);
        try self.writeRecords(records);
        std.debug.print("perf_bench: {s} {s} run {d}: {d} records ({s})\n", .{ @tagName(pin.name), page.page, run_index, records.len, @tagName(ending) });
        // Its text before the arenas go (the guard's line reads it).
        self.noteEnd(page, run_index, ending);
        return LaunchEnd.of(ending);
    }

    const WaitFor = enum { done, loaded_count };

    /// Until the page is done (or `n` instances have loaded), the engine
    /// exits, its driver fails, the page's time runs out, or a STOP file.
    fn waitFor(self: *Runner, c: *Collector, p: *Process, driver: *?Driver, page: suite_mod.Page, what: WaitFor, n: usize) collector_mod.Ending {
        const deadline_ms: f64 = @floatFromInt(@as(u64, page.timeout_s) * 1000);
        while (true) {
            {
                self.live.mutex.lockUncancelable(self.io);
                defer self.live.mutex.unlock(self.io);
                switch (what) {
                    .done => if (c.done) return .done,
                    .loaded_count => if (c.loads >= n) return .done,
                }
                if (self.live.sinceStart() > deadline_ms) return .{ .timeout = page.timeout_s };
            }
            if (p.hasExited()) return .{ .exited = self.copyUnderLock(c, p.termText()) };
            if (driver.*) |*d| if (d.failed()) |msg| return .{ .driver = self.copyUnderLock(c, msg) };
            if (self.stopped()) return .stopped;
            Io.sleep(self.io, .fromMilliseconds(20), .awake) catch {};
        }
    }

    /// `text` in the collector's arena (the server's threads use it too).
    fn copyUnderLock(self: *Runner, c: *Collector, text: []const u8) []const u8 {
        self.live.mutex.lockUncancelable(self.io);
        defer self.live.mutex.unlock(self.io);
        return c.arena.dupe(u8, text) catch "(out of memory)";
    }

    fn pageUrl(self: *const Runner, arena: Allocator, page: suite_mod.Page, token: []const u8) ![]const u8 {
        const url = try pageUrlFor(arena, self.server.port(), page, token, self.config.iterations, self.config.warmup, self.config.settle_ms);
        return if (self.config.collected) collectedUrl(arena, page, url) else url;
    }

    fn writeRecords(self: *Runner, records: []const journal.Record) !void {
        for (records) |r| {
            journal.validate(r) catch |err| {
                std.debug.print("perf_bench: a record of {s} failed validation ({t}); written anyway\n", .{ r.workload, err });
            };
            try journal.writeLine(&self.journal_writer.interface, r);
            self.records += 1;
        }
        try self.journal_writer.interface.flush();
    }
};

/// Whether `--only=<text>` runs `page`: its name or one of its workloads'
/// contains the text. A selected page runs all its workloads.
pub fn pageSelected(page: suite_mod.Page, only: ?[]const u8) bool {
    const text = only orelse return true;
    if (std.mem.indexOf(u8, page.page, text) != null) return true;
    for (page.workloads) |w| if (std.mem.indexOf(u8, w, text) != null) return true;
    return false;
}

/// The URL a launch opens: the page, with the harness's query
/// (tests/perf/harness.js). A retained page's settle time is its own (the
/// suite's `settle_ms`, the idle time before each reading) and it adds the
/// number of objects to make, `count`, so every engine makes the same
/// number; every other page's URL is what it always was.
pub fn pageUrlFor(arena: Allocator, port: u16, page: suite_mod.Page, token: []const u8, iterations: u32, warmup: u32, settle_ms: u32) ![]const u8 {
    if (page.kind == .retained) return std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/{s}?perf={s}&iterations={d}&warmup={d}&steps={d}&settle={d}&count={d}", .{
        port, page.page, token, iterations, warmup, page.steps, page.settle_ms, page.count,
    });
    return std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/{s}?perf={s}&iterations={d}&warmup={d}&steps={d}&settle={d}", .{
        port, page.page, token, iterations, warmup, page.steps, settle_ms,
    });
}

/// A timed page's URL in a collected pass (`Config.collected`): the page's
/// own URL with `collect=1`, which tells the harness to ask for a
/// collection after each workload's settled mark. Every other kind of page
/// keeps its URL: a retained page collects by itself, and a chain, an idle
/// page and an instances row have no settled mark.
pub fn collectedUrl(arena: Allocator, page: suite_mod.Page, url: []const u8) ![]const u8 {
    if (page.kind != .timed) return url;
    return std.fmt.allocPrint(arena, "{s}&collect=1", .{url});
}

/// Ends `pids` by exact pid: SIGTERM to each, then SIGKILL to any still
/// there after `grace_ms`. How many needed SIGKILL. Never by name: a name
/// is not a process (crane_guard's rule, and Safari's WebKit processes may
/// be another app's).
pub fn endProcesses(io: Io, pids: []const i32, grace_ms: u32) usize {
    for (pids) |p| std.posix.kill(p, .TERM) catch {};
    var waited: u32 = 0;
    while (waited < grace_ms) : (waited += 20) {
        const left = for (pids) |p| {
            if (proc.usageOf(p) != null) break true;
        } else false;
        if (!left) return 0;
        Io.sleep(io, .fromMilliseconds(20), .awake) catch {};
    }
    var killed: usize = 0;
    for (pids) |p| if (proc.usageOf(p) != null) {
        std.posix.kill(p, .KILL) catch continue;
        killed += 1;
    };
    // Until the kernel has taken them (a KILLed process is gone at once
    // unless it is a zombie its parent has not reaped).
    var after: u32 = 0;
    while (after < 2000) : (after += 20) {
        const left = for (pids) |p| {
            if (proc.usageOf(p) != null) break true;
        } else false;
        if (!left) break;
        Io.sleep(io, .fromMilliseconds(20), .awake) catch {};
    }
    return killed;
}

const max_rest = 32;

/// The pid of a running process of the engine's app, if any: a launch
/// would not be the only one using it.
pub fn appRunning(names: []const []const u8) ?i32 {
    var pids: [8]i32 = undefined;
    const n = proc.named(names, 0, &pids);
    return if (n > 0) pids[0] else null;
}

/// The protocol side of a launch: Lightpanda's CDP session, Safari's
/// WebDriver session, on a thread of their own (each blocks while the page
/// runs), with the error that ended it if one did.
const Driver = struct {
    io: Io,
    gpa: Allocator,
    drive: engines.Drive,
    port: u16,
    url: []const u8,
    thread: ?std.Thread = null,
    stop: std.atomic.Value(bool) = .init(false),
    err_buf: [256]u8 = undefined,
    err_len: std.atomic.Value(usize) = .init(0),
    ws: cdp.WebSocket = undefined,
    ws_open: std.atomic.Value(bool) = .init(false),
    safari: ?webdriver.Session = null,
    /// Set (release) once `safari` is written by the driver thread.
    safari_ready: std.atomic.Value(bool) = .init(false),
    arena: std.heap.ArenaAllocator = undefined,

    fn start(self: *Driver) !void {
        self.arena = .init(self.gpa);
        self.thread = try std.Thread.spawn(.{}, body, .{self});
    }

    fn fail(self: *Driver, comptime fmt: []const u8, args: anytype) void {
        const text = std.fmt.bufPrint(&self.err_buf, fmt, args) catch "driver failed";
        self.err_len.store(text.len, .release);
    }

    fn failed(self: *Driver) ?[]const u8 {
        const n = self.err_len.load(.acquire);
        return if (n == 0) null else self.err_buf[0..n];
    }

    fn body(self: *Driver) void {
        const arena = self.arena.allocator();
        switch (self.drive) {
            .argv => {},
            .cdp => {
                // Lightpanda's CDP server takes a moment to listen.
                var tries: u32 = 0;
                while (true) : (tries += 1) {
                    self.ws.connect(self.io, self.port, "/") catch |err| {
                        if (tries >= 100 or self.stop.load(.acquire)) return self.fail("CDP connect: {t}", .{err});
                        Io.sleep(self.io, .fromMilliseconds(100), .awake) catch {};
                        continue;
                    };
                    break;
                }
                self.ws_open.store(true, .release);
                var session: cdp.Session = .{ .ws = &self.ws, .gpa = arena };
                cdp.openPage(arena, &session, self.url) catch |err| return self.fail("CDP: {t}", .{err});
                // Keep the connection: read (and drop) events until it closes.
                while (!self.stop.load(.acquire)) {
                    const msg = self.ws.readText(self.gpa) catch return;
                    self.gpa.free(msg);
                }
            },
            .webdriver => {
                const s = webdriver.Session.create(arena, self.io, self.port, 15_000) catch |err| return self.fail("WebDriver New Session: {t}", .{err});
                self.safari = s;
                self.safari_ready.store(true, .release);
                s.navigate(self.url) catch |err| return self.fail("WebDriver Navigate To: {t}", .{err});
            },
        }
    }

    /// Before the engine's processes end: the WebDriver session is deleted
    /// (Safari closes the window it opened), and the CDP connection shut
    /// down, which ends its read loop (shutdown, not close: closing a socket
    /// another thread reads is a race on its descriptor).
    fn beginStop(self: *Driver) void {
        self.stop.store(true, .release);
        if (self.safari_ready.load(.acquire)) {
            // Not the driver thread's arena: that thread may be in Navigate To.
            var buf: [64 * 1024]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buf);
            self.safari.?.delete(fba.allocator());
        }
        if (self.ws_open.load(.acquire)) self.ws.stream.shutdown(self.io, .both) catch {};
    }

    /// After the engine's processes ended: join the thread, close.
    fn join(self: *Driver) void {
        self.stop.store(true, .release);
        if (self.thread) |t| t.join();
        if (self.ws_open.load(.acquire)) self.ws.close();
        self.ws_open.store(false, .release);
        self.thread = null;
        self.arena.deinit();
    }
};

const testing = std.testing;

test "ending processes by exact pid: TERM first, KILL after the grace time" {
    if (!proc.supported) return error.SkipZigTest;
    const io = testing.io;
    // One that ends on TERM, one that ignores it.
    var polite = try std.process.spawn(io, .{ .argv = &.{ "/bin/sleep", "30" }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore });
    var stubborn = try std.process.spawn(io, .{ .argv = &.{ "/bin/sh", "-c", "trap '' TERM; while :; do sleep 0.1; done" }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore });
    // The pids, read BEFORE the reapers own the Child values: Child.wait
    // ends in Io.Threaded.childCleanupPosix, which writes `child.id = null`
    // on the reaper's thread, so a read of `id` here after the spawn raced
    // with it (ThreadSanitizer, -Dsanitize-thread: the reaper's write at
    // Threaded.zig childCleanupPosix against this thread's read of
    // `polite.id`; the runner itself copies the pid before it starts its
    // waiter, `Process.pid`).
    const pids = [_]i32{ polite.id.?, stubborn.id.? };
    // Reap each as it ends, as launchd does for Safari: a zombie still reads.
    const Reaper = struct {
        fn run(c: *std.process.Child, i: Io) void {
            _ = c.wait(i) catch {};
        }
    };
    const t1 = try std.Thread.spawn(.{}, Reaper.run, .{ &polite, io });
    const t2 = try std.Thread.spawn(.{}, Reaper.run, .{ &stubborn, io });
    // Let the shell install its trap.
    Io.sleep(io, .fromMilliseconds(300), .awake) catch {};
    const killed = endProcesses(io, &pids, 1000);
    const gone = [2]bool{ proc.usageOf(pids[0]) == null, proc.usageOf(pids[1]) == null };
    // Whatever endProcesses did, the test leaves nothing behind (a failing
    // version must fail, not hang on a child that ignores TERM).
    for (pids) |p| std.posix.kill(p, .KILL) catch {};
    t1.join();
    t2.join();
    // Only the one that ignored TERM needed KILL; both were gone when it returned.
    try testing.expectEqual(@as(usize, 1), killed);
    try testing.expect(gone[0] and gone[1]);
}

test "a run's guard: N launches of one engine in a row that time out or crash stop it; a finished page starts the count again" {
    const none: ?FailureGuard.Streak = null;
    var g: FailureGuard = .{ .max = 3 };
    // The two sides alternate; only one of them is failing.
    try testing.expectEqual(none, g.note(.crane, .timeout));
    try testing.expectEqual(none, g.note(.crane_base, .done));
    try testing.expectEqual(none, g.note(.crane, .crash));
    // A finished page starts the count again.
    try testing.expectEqual(none, g.note(.crane, .done));
    try testing.expectEqual(none, g.note(.crane, .timeout));
    try testing.expectEqual(none, g.note(.crane, .timeout));
    // A launch that could not be driven is neither: the count stands.
    try testing.expectEqual(none, g.note(.crane, .other));
    const streak = g.note(.crane, .crash).?;
    try testing.expectEqual(@as(u32, 2), streak.timeouts);
    try testing.expectEqual(@as(u32, 1), streak.crashes);
    // The other side's count is its own.
    try testing.expectEqual(none, g.note(.crane_base, .timeout));
    try testing.expectEqual(none, g.note(.crane_base, .timeout));
    try testing.expectEqual(@as(u32, 3), g.note(.crane_base, .timeout).?.timeouts);
    // 0: never.
    var off: FailureGuard = .{ .max = 0 };
    for (0..10) |_| try testing.expectEqual(none, off.note(.crane, .timeout));

    // The line a stopped run ends with names the engine, the crashes and the
    // last launch; the exit status says which ending it was.
    var buf: [512]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    const failing: Outcome = .{ .failing = .{ .engine = .crane, .streak = streak, .last = "workloads/attributes.html run 0: the engine exited before the page finished: signal 6" } };
    try failing.line(&w);
    try testing.expectEqualStrings("perf_bench: STOPPED: 3 launches of crane in a row ended without the page finishing (2 timed out, 1 crashed); the last: workloads/attributes.html run 0: the engine exited before the page finished: signal 6\n", w.buffered());
    try testing.expectEqual(@as(u8, 4), failing.exitCode());
    try testing.expectEqual(@as(u8, 3), (Outcome{ .stopped = {} }).exitCode());
    try testing.expectEqual(@as(u8, 0), (Outcome{ .complete = {} }).exitCode());
    // The endings of a launch, as the guard reads them.
    try testing.expectEqual(LaunchEnd.timeout, LaunchEnd.of(.{ .timeout = 600 }));
    try testing.expectEqual(LaunchEnd.crash, LaunchEnd.of(.{ .exited = "signal 11" }));
    try testing.expectEqual(LaunchEnd.other, LaunchEnd.of(.{ .driver = "CDP connect" }));
    try testing.expectEqual(LaunchEnd.done, LaunchEnd.of(.done));
    try testing.expectEqual(LaunchEnd.stopped, LaunchEnd.of(.stopped));
}

test "perf_bench check's launches: every pinned engine needs an ok record of the check page, and each that has none is named" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sha = "abababababababababababababababababababababababababababababababab";
    const pins = [_]engines.Pin{
        .{ .name = .crane, .version = "tip", .build = "release", .binary = "/t/repl", .sha256 = sha },
        .{ .name = .crane_base, .version = "main", .build = "release", .binary = "/m/repl", .sha256 = sha },
        .{ .name = .chrome, .version = "157", .build = "stable", .binary = "/c/chrome", .sha256 = sha },
    };
    const record: journal.Record = .{
        .format = journal.format_name,
        .round = 0,
        .time = "2026-11-24T22:00:00Z",
        .host = .{ .name = "h", .os = "macOS", .arch = "aarch64", .cpu = "M", .cores = 8, .memory_bytes = 1 },
        .engine = .{ .name = .crane, .version = "tip", .build = "release", .binary = "/t/repl", .binary_sha256 = sha, .flags = &.{} },
        .page = check_page.page,
        .workload = "overhead.empty",
        .kind = .timed,
        .run = 0,
        .status = .ok,
    };
    // 2026-11-23's console: every script threw, so no result in the time.
    var broken = record;
    broken.engine.name = .crane_base;
    broken.status = .timeout;
    broken.message = "no result in 60 s";
    // The page's own row is not the workload's.
    var page_row = record;
    page_row.engine.name = .chrome;
    page_row.workload = "page.overhead";
    const problems = try checkProblems(a, &.{ record, broken, page_row }, &pins);
    try testing.expectEqual(@as(usize, 2), problems.len);
    try testing.expectEqualStrings("crane_base: timeout on workloads/overhead.html: no result in 60 s", problems[0]);
    try testing.expectEqualStrings("chrome: no record of overhead.empty (the launch made none)", problems[1]);
    // Every engine answered: nothing to say.
    var chrome_ok = record;
    chrome_ok.engine.name = .chrome;
    var base_ok = record;
    base_ok.engine.name = .crane_base;
    try testing.expectEqual(@as(usize, 0), (try checkProblems(a, &.{ record, base_ok, chrome_ok }, &pins)).len);
}

test "a page's URL: a retained page's count and settle time; every other page's as it was" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    // The URL every page had before retained pages existed, byte for byte.
    const timed: suite_mod.Page = .{ .page = "workloads/attributes.html", .kind = .timed, .workloads = &.{"dom.getter-loop"} };
    try testing.expectEqualStrings("http://127.0.0.1:8123/workloads/attributes.html?perf=chrome.2.0.0&iterations=10&warmup=3&steps=0&settle=500", try pageUrlFor(a, 8123, timed, "chrome.2.0.0", 10, 3, 500));
    const chain: suite_mod.Page = .{ .page = "load/news.html", .kind = .chain, .steps = 10, .workloads = &.{"load.news"} };
    try testing.expectEqualStrings("http://127.0.0.1:8123/load/news.html?perf=t.0&iterations=10&warmup=3&steps=10&settle=500", try pageUrlFor(a, 8123, chain, "t.0", 10, 3, 500));
    const idle: suite_mod.Page = .{ .page = "memory/idle.html", .kind = .idle, .settle_ms = 3000, .workloads = &.{"memory.idle-page"} };
    try testing.expectEqualStrings("http://127.0.0.1:8123/memory/idle.html?perf=t.0&iterations=10&warmup=3&steps=0&settle=500", try pageUrlFor(a, 8123, idle, "t.0", 10, 3, 500));
    // A retained page: its own settle time and its count.
    const retained: suite_mod.Page = .{ .page = "memory/elements-detached-div.html", .kind = .retained, .count = 100000, .settle_ms = 3000, .workloads = &.{"elements.detached-div"} };
    try testing.expectEqualStrings("http://127.0.0.1:8123/memory/elements-detached-div.html?perf=crane.17.0.0&iterations=10&warmup=3&steps=0&settle=3000&count=100000", try pageUrlFor(a, 8123, retained, "crane.17.0.0", 10, 3, 500));
}

test "a collected pass: a timed page's URL asks for it, and no other page's URL changes" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const timed: suite_mod.Page = .{ .page = "workloads/streams.html", .kind = .timed, .workloads = &.{"streams.reader"} };
    const plain = try pageUrlFor(a, 8123, timed, "crane.2.0.0", 10, 3, 500);
    try testing.expectEqualStrings("http://127.0.0.1:8123/workloads/streams.html?perf=crane.2.0.0&iterations=10&warmup=3&steps=0&settle=500&collect=1", try collectedUrl(a, timed, plain));
    for ([_]suite_mod.Page{
        .{ .page = "load/news.html", .kind = .chain, .steps = 10, .workloads = &.{"load.news"} },
        .{ .page = "memory/idle.html", .kind = .idle, .settle_ms = 3000, .workloads = &.{"memory.idle-page"} },
        .{ .page = "memory/instance.html", .kind = .instances, .instances = 4, .workloads = &.{"memory.instances"} },
        .{ .page = "memory/elements-detached-div.html", .kind = .retained, .count = 100000, .settle_ms = 3000, .workloads = &.{"elements.detached-div"} },
    }) |page| {
        const url = try pageUrlFor(a, 8123, page, "t.0", 10, 3, 500);
        try testing.expectEqualStrings(url, try collectedUrl(a, page, url));
    }
}

test "a launch is refused while its engine's app is already running" {
    if (!proc.supported) return error.SkipZigTest;
    // This test's own process stands in for a Safari left running.
    const me: i32 = @intCast(std.c.getpid());
    var name_buf: [256]u8 = undefined;
    const name = try proc.nameOf(me, &name_buf);
    try testing.expect(appRunning(&.{name}) != null);
    try testing.expectEqual(@as(?i32, null), appRunning(&.{"no-such-process-perf0b"}));
    try testing.expectEqual(@as(?i32, null), appRunning(&.{}));
}
