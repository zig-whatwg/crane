//! perf_bench: Crane's benchmark suite runner and its /performance/ report
//! (docs/performance.md).
//!
//!   perf_bench run --suite=<suite.json> --root=<tests/perf> --out=<dir>
//!                  --round=<n> --runs=<n> --pin=<file> [--pin=<file> ...]
//!                  [--profiles=<dir>] [--stop-file=<f>] [--only=<text>]
//!                  [--iterations=<n>] [--warmup=<n>] [--settle-ms=<n>] [--port=<n>]
//!       every engine pinned on every page of the suite, <runs> times, in
//!       alternating order; the journal is <out>/journal.jsonl
//!   perf_bench check --suite=... --root=... --pin=<file> ...
//!       the run's input checks alone (window scripts run them first): the
//!       suite against its pages, each pin readable, each binary there and
//!       matching its SHA-256
//!   perf_bench check-suite --suite=... --root=...
//!       the suite against its pages (zig build test runs it)
//!   perf_bench gc-bench --gc-bench=<binary> --pin=<crane pin> --out=<dir>
//!                  --round=<n> --runs=<n> [--rows=a,b,...]
//!       gc_bench's rows, the Crane-only rows, into <out>/journal.jsonl
//!   perf_bench validate <journal.jsonl> ...
//!       read journals strictly; say what they hold
//!   perf_bench report --journals=<dir> --out=<dir> [--site-url=<url>]
//!       write /performance/ (index.html, card.png) from every *.jsonl
//!       below <dir>
//!   perf_bench serve --root=<tests/perf> [--port=<n>]
//!       the pages alone, for a person to open in a browser

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const journal = @import("journal.zig");
pub const stats = @import("stats.zig");
pub const suite = @import("suite.zig");
pub const proc = @import("proc.zig");
pub const server = @import("server.zig");
pub const engines = @import("engines.zig");
pub const cdp = @import("cdp.zig");
pub const webdriver = @import("webdriver.zig");
pub const collector = @import("collector.zig");
pub const runner = @import("runner.zig");
pub const gcbench = @import("gcbench.zig");
pub const report = @import("report.zig");
pub const card = @import("card.zig");

const usage =
    \\usage: perf_bench run|check|check-suite|gc-bench|validate|report|serve [options]
    \\       (docs/performance.md; tools/perf_bench/main.zig lists every option)
    \\
;

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print("perf_bench: " ++ fmt ++ "\n", args);
    std.process.exit(2);
}

/// `--key=value` options; repeated keys kept in order.
const Args = struct {
    positional: std.ArrayList([]const u8) = .empty,
    keys: std.ArrayList([]const u8) = .empty,
    values: std.ArrayList([]const u8) = .empty,

    fn parse(arena: Allocator, argv: []const []const u8) !Args {
        var a: Args = .{};
        for (argv) |arg| {
            if (std.mem.startsWith(u8, arg, "--")) {
                const eq = std.mem.indexOfScalar(u8, arg, '=');
                try a.keys.append(arena, arg[2 .. eq orelse arg.len]);
                try a.values.append(arena, if (eq) |e| arg[e + 1 ..] else "");
            } else try a.positional.append(arena, arg);
        }
        return a;
    }

    fn get(a: *const Args, key: []const u8) ?[]const u8 {
        var i = a.keys.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, a.keys.items[i], key)) return a.values.items[i];
        }
        return null;
    }

    fn need(a: *const Args, key: []const u8) []const u8 {
        return a.get(key) orelse fail("--{s} is required", .{key});
    }

    fn all(a: *const Args, arena: Allocator, key: []const u8) ![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        for (a.keys.items, a.values.items) |k, v| if (std.mem.eql(u8, k, key)) try out.append(arena, v);
        return out.items;
    }

    fn int(a: *const Args, comptime T: type, key: []const u8, default: T) T {
        const v = a.get(key) orelse return default;
        return std.fmt.parseInt(T, v, 10) catch fail("--{s}={s} is not a number", .{ key, v });
    }
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const argv = try init.minimal.args.toSlice(arena);
    if (argv.len < 2) {
        std.debug.print("{s}", .{usage});
        std.process.exit(2);
    }
    const cmd = argv[1];
    const args = try Args.parse(arena, argv[2..]);
    if (std.mem.eql(u8, cmd, "check-suite")) {
        const s = try loadSuite(arena, io, args.need("suite"), args.need("root"));
        std.debug.print("perf_bench: suite OK: {d} pages, {d} workloads\n", .{ s.pages.len, countWorkloads(s) });
    } else if (std.mem.eql(u8, cmd, "check")) {
        _ = try checkInputs(arena, io, &args);
        std.debug.print("perf_bench: inputs OK\n", .{});
    } else if (std.mem.eql(u8, cmd, "run")) {
        const inputs = try checkInputs(arena, io, &args);
        const out = args.need("out");
        var r = runner.Runner.init(init.gpa, io, .{
            .suite = inputs.suite,
            .root = args.need("root"),
            .out_dir = out,
            .profile_root = args.get("profiles") orelse try std.fmt.allocPrint(arena, "{s}/profiles", .{out}),
            .round = args.int(u32, "round", 0),
            .runs = args.int(u32, "runs", 1),
            .pins = inputs.pins,
            .host = try hostInfo(arena, io),
            .environ = init.environ_map,
            .stop_file = args.get("stop-file"),
            .only = args.get("only"),
            .iterations = args.int(u32, "iterations", 10),
            .warmup = args.int(u32, "warmup", 3),
            .settle_ms = args.int(u32, "settle-ms", 500),
            .port = args.int(u16, "port", 0),
        });
        try r.run();
    } else if (std.mem.eql(u8, cmd, "gc-bench")) {
        try runGcBench(init.gpa, arena, io, &args);
    } else if (std.mem.eql(u8, cmd, "validate")) {
        if (args.positional.items.len == 0) fail("validate: name one or more journals", .{});
        var bad = false;
        for (args.positional.items) |path| {
            const bytes = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30)) catch |err| fail("{s}: {t}", .{ path, err });
            var failure: journal.Failure = .{};
            const records = journal.parseJournal(arena, bytes, &failure) catch |err| {
                std.debug.print("{s}:{d}: {t}\n", .{ path, failure.line, err });
                bad = true;
                continue;
            };
            var ok: usize = 0;
            for (records) |r| if (r.status == .ok) {
                ok += 1;
            };
            std.debug.print("{s}: {d} records, {d} ok\n", .{ path, records.len, ok });
        }
        if (bad) std.process.exit(1);
    } else if (std.mem.eql(u8, cmd, "report")) {
        try writeReport(arena, io, &args);
    } else if (std.mem.eql(u8, cmd, "serve")) {
        const s = try server.Server.start(init.gpa, io, .{ .root = args.need("root"), .port = args.int(u16, "port", 8000) });
        defer s.stop();
        std.debug.print("perf_bench: serving {s} on http://127.0.0.1:{d}/ (Ctrl+C ends)\n", .{ args.need("root"), s.port() });
        while (true) Io.sleep(io, .fromSeconds(3600), .awake) catch {};
    } else {
        std.debug.print("{s}", .{usage});
        std.process.exit(2);
    }
}

fn countWorkloads(s: suite.Suite) usize {
    var n: usize = 0;
    for (s.pages) |p| n += p.workloads.len;
    return n;
}

const PageReader = struct {
    io: Io,
    root: []const u8,
    fn read(self: *const PageReader, arena: Allocator, path: []const u8) ?[]const u8 {
        const full = std.fmt.allocPrint(arena, "{s}/{s}", .{ self.root, path }) catch return null;
        return Io.Dir.cwd().readFileAlloc(self.io, full, arena, .limited(16 << 20)) catch null;
    }
};

/// The suite, held to its pages: exits 2 naming each problem.
fn loadSuite(arena: Allocator, io: Io, path: []const u8, root: []const u8) !suite.Suite {
    const bytes = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20)) catch |err| fail("{s}: {t}", .{ path, err });
    const s = suite.parse(arena, bytes) catch |err| fail("{s}: {t}", .{ path, err });
    const reader: PageReader = .{ .io = io, .root = root };
    const problems = try suite.check(arena, s, &reader, PageReader.read);
    for (problems) |p| std.debug.print("{s}/{s}: {s} {s}\n", .{ root, p.page, p.what, p.workload });
    if (problems.len > 0) fail("{d} problems between {s} and its pages", .{ problems.len, path });
    return s;
}

const Inputs = struct { suite: suite.Suite, pins: []const engines.Pin };

/// The window rule's input checks (every list non-empty, every binary its
/// pinned bytes), with each count printed.
fn checkInputs(arena: Allocator, io: Io, args: *const Args) !Inputs {
    const s = try loadSuite(arena, io, args.need("suite"), args.need("root"));
    std.debug.print("perf_bench: suite: {d} pages, {d} workloads\n", .{ s.pages.len, countWorkloads(s) });
    const pin_paths = try args.all(arena, "pin");
    if (pin_paths.len == 0) fail("no --pin: nothing to run", .{});
    var pins: std.ArrayList(engines.Pin) = .empty;
    for (pin_paths) |path| {
        const text = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 * 1024)) catch |err| fail("pin {s}: {t}", .{ path, err });
        const pin = engines.parsePin(arena, text) catch |err| fail("pin {s}: {t}", .{ path, err });
        var hex: [64]u8 = undefined;
        engines.sha256File(io, pin.binary, &hex) catch |err| fail("{s}: {s}: {t}", .{ path, pin.binary, err });
        if (!std.mem.eql(u8, &hex, pin.sha256)) fail("{s}: {s} is not the pinned binary (sha256 {s}, pinned {s})", .{ path, pin.binary, &hex, pin.sha256 });
        if (pin.webdriver) |wd| Io.Dir.cwd().access(io, wd, .{}) catch fail("{s}: webdriver {s} missing", .{ path, wd });
        for (pins.items) |p| if (p.name == pin.name) fail("two pins for {s}", .{@tagName(pin.name)});
        std.debug.print("perf_bench: {s} {s}: {s} (sha256 OK)\n", .{ @tagName(pin.name), pin.version, pin.binary });
        try pins.append(arena, pin);
    }
    std.debug.print("perf_bench: {d} engines pinned\n", .{pins.items.len});
    return .{ .suite = s, .pins = pins.items };
}

/// A command's first line of output, trimmed; "" when it fails.
fn capture(arena: Allocator, io: Io, argv: []const []const u8) []const u8 {
    const r = std.process.run(arena, io, .{ .argv = argv }) catch return "";
    return std.mem.trim(u8, r.stdout, " \t\r\n");
}

/// The measuring host, as every row records it.
pub fn hostInfo(arena: Allocator, io: Io) !journal.Host {
    const name = capture(arena, io, &.{ "hostname", "-s" });
    const product = capture(arena, io, &.{ "sw_vers", "-productVersion" });
    const build_v = capture(arena, io, &.{ "sw_vers", "-buildVersion" });
    const cpu = capture(arena, io, &.{ "sysctl", "-n", "machdep.cpu.brand_string" });
    const cores = std.fmt.parseInt(u32, capture(arena, io, &.{ "sysctl", "-n", "hw.ncpu" }), 10) catch 0;
    const mem = std.fmt.parseInt(u64, capture(arena, io, &.{ "sysctl", "-n", "hw.memsize" }), 10) catch 0;
    return .{
        .name = if (name.len > 0) name else "unknown",
        .os = if (product.len > 0) try std.fmt.allocPrint(arena, "macOS {s} ({s})", .{ product, build_v }) else @tagName(builtin.os.tag),
        .arch = @tagName(builtin.cpu.arch),
        .cpu = if (cpu.len > 0) cpu else "unknown",
        .cores = cores,
        .memory_bytes = mem,
    };
}

fn runGcBench(gpa: Allocator, arena: Allocator, io: Io, args: *const Args) !void {
    const bin = args.need("gc-bench");
    const pin_text = Io.Dir.cwd().readFileAlloc(io, args.need("pin"), arena, .limited(64 * 1024)) catch |err| fail("pin: {t}", .{err});
    const pin = engines.parsePin(arena, pin_text) catch |err| fail("pin: {t}", .{err});
    if (pin.name != .crane) fail("gc-bench rows are Crane's: the pin is {s}'s", .{@tagName(pin.name)});
    var gc_hex: [64]u8 = undefined;
    engines.sha256File(io, bin, &gc_hex) catch |err| fail("{s}: {t}", .{ bin, err });
    var rows: std.ArrayList(gcbench.Row) = .empty;
    if (args.get("rows")) |list| {
        var it = std.mem.tokenizeScalar(u8, list, ',');
        while (it.next()) |name| try rows.append(arena, gcbench.find(name) orelse fail("no gc_bench row {s}", .{name}));
    } else try rows.appendSlice(arena, &gcbench.rows);
    const out = args.need("out");
    try Io.Dir.cwd().createDirPath(io, out);
    var dir = try Io.Dir.cwd().openDir(io, out, .{});
    defer dir.close(io);
    var file = try dir.createFile(io, "journal.jsonl", .{ .exclusive = true });
    defer file.close(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.writer(io, &buf);
    const host = try hostInfo(arena, io);
    const runs = args.int(u32, "runs", 5);
    const round = args.int(u32, "round", 0);
    const stop_file = args.get("stop-file");
    var run_i: u32 = 0;
    outer: while (run_i < runs) : (run_i += 1) {
        for (rows.items) |row| {
            if (stop_file) |f| if (Io.Dir.cwd().access(io, f, .{})) |_| break :outer else |_| {};
            var ra: std.heap.ArenaAllocator = .init(gpa);
            defer ra.deinit();
            const a = ra.allocator();
            const cmd = try gcbench.argv(a, bin, row);
            const ts = Io.Clock.real.now(io);
            const secs: u64 = @intCast(@divFloor(ts.nanoseconds, std.time.ns_per_s));
            const es: std.time.epoch.EpochSeconds = .{ .secs = secs };
            const yd = es.getEpochDay().calculateYearDay();
            const md = yd.calculateMonthDay();
            const ds = es.getDaySeconds();
            const time = try std.fmt.allocPrint(a, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{ yd.year, md.month.numeric(), md.day_index + 1, ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute() });
            // In gc_bench's own directory: it finds whatwg_snapshot.bin there, as
            // the lanes' series run it (`cd <bins> && ./gc_bench`).
            const result = std.process.run(a, io, .{ .argv = cmd, .cwd = .{ .path = std.fs.path.dirname(bin) orelse "." } }) catch |err| fail("gc_bench: {t}", .{err});
            const text = try std.mem.concat(a, u8, &.{ result.stdout, result.stderr });
            const f = gcbench.parse(text);
            var rec: journal.Record = .{
                .format = journal.format_name,
                .round = round,
                .time = time,
                .host = host,
                .engine = .{ .name = .crane, .version = pin.version, .build = pin.build, .commit = pin.commit, .optimize = pin.optimize, .v8 = pin.v8, .binary = bin, .binary_sha256 = &gc_hex, .flags = cmd[3..] },
                .page = "gc_bench",
                .workload = try std.fmt.allocPrint(a, "gc-bench.{s}", .{row.name}),
                .kind = .gc_bench,
                .run = run_i,
                .status = .ok,
                .ops = row.cycles,
                .instructions = f.instructions,
                .counters = try gcbench.counters(a, f),
            };
            if (f.wall_s) |s| rec.wall_ms = try a.dupe(f64, &.{s * 1000.0});
            if (f.peak_footprint) |p| rec.memory = .{ .footprint_start = 0, .footprint_end = p, .footprint_peak = p, .resident_end = f.max_rss orelse 0, .processes = 1 };
            const exited_ok = switch (result.term) {
                .exited => |code| code == 0,
                else => false,
            };
            if (!exited_ok or rec.wall_ms.len == 0 or rec.memory == null) {
                rec.status = .crash;
                rec.message = try std.fmt.allocPrint(a, "gc_bench ended {f}", .{result.term});
            }
            try journal.writeLine(&w.interface, rec);
            try w.interface.flush();
            std.debug.print("perf_bench: gc-bench.{s} run {d}: {s}\n", .{ row.name, run_i, @tagName(rec.status) });
        }
    }
}

/// Every *.jsonl below `dir`.
fn readJournals(arena: Allocator, io: Io, dir_path: []const u8) ![]const journal.Record {
    var dir = Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| fail("{s}: {t}", .{ dir_path, err });
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    var paths: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |e| {
        if (e.kind != .file or !std.mem.endsWith(u8, e.basename, ".jsonl")) continue;
        try paths.append(arena, try arena.dupe(u8, e.path));
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lt);
    var all: std.ArrayList(journal.Record) = .empty;
    for (paths.items) |p| {
        const bytes = try dir.readFileAlloc(io, p, arena, .limited(1 << 30));
        var failure: journal.Failure = .{};
        const records = journal.parseJournal(arena, bytes, &failure) catch |err| fail("{s}/{s}:{d}: {t}", .{ dir_path, p, failure.line, err });
        try all.appendSlice(arena, records);
    }
    if (all.items.len == 0) fail("no journal records below {s}", .{dir_path});
    std.debug.print("perf_bench: {d} records from {d} journals\n", .{ all.items.len, paths.items.len });
    return all.items;
}

fn writeReport(arena: Allocator, io: Io, args: *const Args) !void {
    const records = try readJournals(arena, io, args.need("journals"));
    const model = try report.build(arena, records);
    const out = try report.render(arena, &model, .{ .site_url = args.get("site-url") orelse "https://zig-whatwg.github.io/crane/" });
    const out_dir = args.need("out");
    try Io.Dir.cwd().createDirPath(io, out_dir);
    var dir = try Io.Dir.cwd().openDir(io, out_dir, .{});
    defer dir.close(io);
    var written: usize = 0;
    for ([_]struct { []const u8, []const u8 }{ .{ "index.html", out.index_html }, .{ "card.png", out.card_png } }) |f| {
        // Only what changed is written (a regeneration on the same journals
        // writes nothing).
        if (dir.readFileAlloc(io, f[0], arena, .limited(f[1].len + 1))) |old| {
            if (std.mem.eql(u8, old, f[1])) continue;
        } else |_| {}
        try dir.writeFile(io, .{ .sub_path = f[0], .data = f[1] });
        written += 1;
    }
    std.debug.print("perf_bench: /performance/ for round {d} in {s}: {d} files written\n", .{ model.latest_round, out_dir, written });
}

test {
    _ = journal;
    _ = stats;
    _ = suite;
    _ = proc;
    _ = server;
    _ = engines;
    _ = cdp;
    _ = webdriver;
    _ = collector;
    _ = runner;
    _ = gcbench;
    _ = report;
    _ = card;
}
