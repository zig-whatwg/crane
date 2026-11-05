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
    stop_file: ?[]const u8 = null,
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

    pub fn init(gpa: Allocator, io: Io, config: Config) Runner {
        return .{ .gpa = gpa, .io = io, .config = config, .live = .{ .io = io } };
    }

    pub fn run(self: *Runner) !void {
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
        var r: u32 = 0;
        outer: while (r < self.config.runs) : (r += 1) {
            for (self.config.suite.pages, 0..) |page, pi| {
                if (!self.selected(page)) continue;
                for (0..pins.len) |k| {
                    const pin = pins[(k + r) % pins.len];
                    if (self.stopped()) break :outer;
                    try self.launchOne(pin, page, @intCast(pi), r);
                }
            }
        }
        try self.journal_writer.interface.flush();
        std.debug.print("perf_bench: {d} launches, {d} records -> {s}/journal.jsonl\n", .{ self.launches, self.records, self.config.out_dir });
    }

    fn selected(self: *const Runner, page: suite_mod.Page) bool {
        const only = self.config.only orelse return true;
        if (std.mem.indexOf(u8, page.page, only) != null) return true;
        for (page.workloads) |w| if (std.mem.indexOf(u8, w, only) != null) return true;
        return false;
    }

    fn stopped(self: *const Runner) bool {
        const f = self.config.stop_file orelse return false;
        Io.Dir.cwd().access(self.io, f, .{}) catch return false;
        std.debug.print("perf_bench: STOP file {s} present: stopping before the next launch\n", .{f});
        return true;
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

    fn launchOne(self: *Runner, pin: engines.Pin, page: suite_mod.Page, page_index: u32, run_index: u32) !void {
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
            return;
        }

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
            const l = try engines.launch(arena, pin, url, profile, protocol_port);
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
            .timed, .chain => ending = self.waitFor(&collector, &processes[0], &drivers[0], page, .done, 0),
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
        return std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/{s}?perf={s}&iterations={d}&warmup={d}&steps={d}&settle={d}", .{
            self.server.port(), page.page, token, self.config.iterations, self.config.warmup, page.steps, self.config.settle_ms,
        });
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
