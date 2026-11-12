//! fw_matrix: the JS framework compatibility matrix's harness (the user,
//! 2026-11-11 08:37 ET: run the frameworks' own test suites in Crane and
//! track them on one report page; 08:41 ET: "We do not run node.js, we only
//! want to run the tests that would run in a browser like integration
//! tests"). The design: tmp/plans/framework-matrix-plan.md.
//!
//!   fw_matrix check [--manifest=<zon>] [--excluded-dir=<dir>]
//!       the manifest and every exclusion list, read strictly; each list
//!       entry belongs to a page (zig build test runs it)
//!   fw_matrix fetch --frameworks-dir=<dir> [--suite=<id>[,<id>...]]
//!       every pinned file downloaded and checked by sha256 into <dir>
//!       (~/crane-frameworks on the run host), the trees made
//!   fw_matrix run --frameworks-dir=<dir> --console=<repl> --crane-commit=<sha>
//!                 --label=<l> --out=<dir> [--generation=<n>] [--suite=<id>,...]
//!                 [--pages=<id>,...] [--parallel=<n>] [--no-exclusions]
//!                 [--stop-file=<f>]
//!       each suite's pages in a fresh console per page; <out>/journal.jsonl
//!       (crane-fw/1) and <out>/console/<suite>-<page>.{out,err}
//!   fw_matrix summary <journal.jsonl> ...
//!       per suite: pages, tests run / passed / failed / errored / excluded
//!       as rendering / not run; every failure with its first assertion
//!   fw_matrix report --journals=<dir> --out=<dir> [--assets=<url>]
//!       the matrix page and a page per framework, from every journal.jsonl
//!       one or two levels below <dir> (report.zig); --assets is where the
//!       WPT site's site.css is, relative to <out> (default "../")
//!   fw_matrix serve --frameworks-dir=<dir> --suite=<id> [--port=<n>]
//!       a suite's tree alone, for a person to open in a browser
//!
//! A tool: std only, on the host (tools/AGENTS.md "Tools are Zig"); no
//! Node, no Python, nothing of Crane's engine.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const journal = @import("journal.zig");
pub const exclusions = @import("exclusions.zig");
pub const manifest = @import("manifest.zig");
pub const readers = @import("readers.zig");
pub const generated = @import("generated.zig");
pub const server = @import("server.zig");
pub const fetch = @import("fetch.zig");
pub const run = @import("run.zig");
pub const report = @import("report.zig");

const usage =
    \\usage: fw_matrix check|fetch|run|summary|report|serve [options]
    \\       (tools/fw_matrix/main.zig lists every option)
    \\
;

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print("fw_matrix: " ++ fmt ++ "\n", args);
    std.process.exit(2);
}

/// `--key=value` options; the last of a repeated key wins.
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

    fn has(a: *const Args, key: []const u8) bool {
        return a.get(key) != null;
    }

    fn need(a: *const Args, key: []const u8) []const u8 {
        return a.get(key) orelse fail("--{s} is required", .{key});
    }

    fn list(a: *const Args, arena: Allocator, key: []const u8) !?[]const []const u8 {
        const v = a.get(key) orelse return null;
        var out: std.ArrayList([]const u8) = .empty;
        var it = std.mem.tokenizeScalar(u8, v, ',');
        while (it.next()) |s| try out.append(arena, s);
        return out.items;
    }
};

const default_manifest = "tools/fw_matrix/frameworks.zon";
const default_excluded = "tools/fw_matrix/excluded";

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const gpa = init.gpa;
    const argv = try init.minimal.args.toSlice(arena);
    if (argv.len < 2) {
        std.debug.print("{s}", .{usage});
        std.process.exit(2);
    }
    const cmd = argv[1];
    const args = try Args.parse(arena, argv[2..]);
    if (std.mem.eql(u8, cmd, "check")) {
        const m = try loadManifest(gpa, arena, io, args.get("manifest") orelse default_manifest);
        const n = try checkLists(arena, io, m, args.get("excluded-dir") orelse default_excluded);
        std.debug.print("fw_matrix: manifest and exclusion lists OK: {d} suites, {d} exclusion entries\n", .{ m.suites.len, n });
    } else if (std.mem.eql(u8, cmd, "fetch")) {
        const m = try loadManifest(gpa, arena, io, args.get("manifest") orelse default_manifest);
        const dir = args.need("frameworks-dir");
        for (try selectSuites(arena, m, try args.list(arena, "suite"))) |s| try fetch.fetchSuite(gpa, io, dir, s);
    } else if (std.mem.eql(u8, cmd, "run")) {
        const m = try loadManifest(gpa, arena, io, args.get("manifest") orelse default_manifest);
        const excluded_dir = args.get("excluded-dir") orelse default_excluded;
        _ = try checkLists(arena, io, m, excluded_dir);
        const console = args.need("console");
        const console_bytes = Io.Dir.cwd().readFileAlloc(io, console, gpa, .limited(2 << 30)) catch |err| fail("{s}: {t}", .{ console, err });
        const console_sha = fetch.sha256Hex(console_bytes);
        gpa.free(console_bytes);
        const generation: ?u32 = if (args.get("generation")) |g| std.fmt.parseInt(u32, g, 10) catch fail("--generation={s} is not a number", .{g}) else null;
        const parallel = if (args.get("parallel")) |p| std.fmt.parseInt(u32, p, 10) catch fail("--parallel={s} is not a number", .{p}) else 2;
        const totals = try run.run(gpa, io, .{
            .suites = try selectSuites(arena, m, try args.list(arena, "suite")),
            .frameworks_dir = args.need("frameworks-dir"),
            .excluded_dir = excluded_dir,
            .console = console,
            .console_sha256 = try arena.dupe(u8, &console_sha),
            .crane_commit = args.need("crane-commit"),
            .label = args.need("label"),
            .generation = generation,
            .out_dir = args.need("out"),
            .pages = try args.list(arena, "pages"),
            .no_exclusions = args.has("no-exclusions"),
            .parallel = parallel,
            .stop_file = args.get("stop-file"),
        });
        const c = totals.counts;
        std.debug.print("fw_matrix: run done{s}: {d} pages ({d} OK); {d} ran: {d} pass, {d} fail; {d} errored; {d} rendering; {d} not run; {d} skipped by the project\n", .{
            if (totals.stopped) " (STOPPED)" else "", totals.pages, totals.pages_ok, c.ran(), c.pass, c.fail, c.errored(), c.rendering, c.not_run, c.project_skip,
        });
        if (totals.missing_exclusions > 0) fail("{d} exclusion entries name tests the pages do not define: the list is out of date", .{totals.missing_exclusions});
        if (totals.stopped) std.process.exit(3);
    } else if (std.mem.eql(u8, cmd, "summary")) {
        if (args.positional.items.len == 0) fail("summary: name one or more journals", .{});
        try summarize(arena, io, args.positional.items);
    } else if (std.mem.eql(u8, cmd, "report")) {
        const m = try loadManifest(gpa, arena, io, args.get("manifest") orelse default_manifest);
        try writeReport(arena, io, m, args.get("excluded-dir") orelse default_excluded, args.need("journals"), args.need("out"), .{ .assets = args.get("assets") orelse "../" });
    } else if (std.mem.eql(u8, cmd, "serve")) {
        const m = try loadManifest(gpa, arena, io, args.get("manifest") orelse default_manifest);
        const s = manifest.find(m, args.need("suite")) orelse fail("no suite {s} in the manifest", .{args.need("suite")});
        const root = try std.fmt.allocPrint(arena, "{s}/{s}", .{ args.need("frameworks-dir"), try manifest.treeName(arena, s) });
        const port: u16 = if (args.get("port")) |p| std.fmt.parseInt(u16, p, 10) catch fail("--port={s}", .{p}) else 8000;
        const srv = try server.Server.start(gpa, io, .{ .root = root, .port = port, .overlays = try run.serverOverlays(arena, s) });
        defer srv.stop();
        std.debug.print("fw_matrix: serving {s} on http://127.0.0.1:{d}/ (Ctrl+C ends)\n", .{ root, srv.port() });
        while (true) Io.sleep(io, .fromSeconds(3600), .awake) catch {};
    } else {
        std.debug.print("{s}", .{usage});
        std.process.exit(2);
    }
}

fn loadManifest(gpa: Allocator, arena: Allocator, io: Io, path: []const u8) !manifest.Manifest {
    const bytes = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 20)) catch |err| fail("{s}: {t}", .{ path, err });
    const z = try arena.dupeSentinel(u8, bytes, 0);
    var f: manifest.Failure = .{};
    return manifest.parse(gpa, arena, z, &f) catch |err| {
        if (err == error.ParseZon) f.diagnostics.log(path);
        fail("{s}: suite {s}, {s}: {t}", .{ path, f.suite, f.what, err });
    };
}

fn selectSuites(arena: Allocator, m: manifest.Manifest, only: ?[]const []const u8) ![]const manifest.Suite {
    const ids = only orelse return m.suites;
    var out: std.ArrayList(manifest.Suite) = .empty;
    for (ids) |id| try out.append(arena, manifest.find(m, id) orelse fail("no suite {s} in the manifest", .{id}));
    return out.items;
}

/// Every suite's list parsed; on a module page's suite every entry's module
/// is a page's (an entry for no page would never be applied). Returns the
/// number of entries.
fn checkLists(arena: Allocator, io: Io, m: manifest.Manifest, dir: []const u8) !usize {
    var total: usize = 0;
    var bad = false;
    for (m.suites) |s| {
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, s.excluded });
        const text = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(16 << 20)) catch |err| fail("{s}: {t}", .{ path, err });
        var pf: exclusions.ParseFailure = .{};
        const entries = exclusions.parse(arena, text, &pf) catch |err| fail("{s}:{d}: {t}", .{ path, pf.line, err });
        total += entries.len;
        for (entries) |e| {
            if (e.file) continue;
            const page_for = for (s.pages) |p| {
                const pm = p.module orelse break true;
                const em = exclusions.qunitModule(e.id) orelse continue;
                if (std.ascii.eqlIgnoreCase(pm, em)) break true;
            } else false;
            if (!page_for) {
                std.debug.print("{s}:{d}: [{s}] belongs to no page of suite {s}\n", .{ path, e.line, e.id, s.id });
                bad = true;
            }
        }
    }
    if (bad) fail("exclusion entries that no page applies", .{});
    return total;
}

const SuiteSummary = struct {
    suite: []const u8,
    framework: []const u8,
    version: []const u8,
    kind: journal.SuiteKind,
    counts: journal.Counts = .{},
    pages: u32 = 0,
    pages_ok: u32 = 0,
    page_problems: std.ArrayList([]const u8) = .empty,
    failures: std.ArrayList(journal.TestRecord) = .empty,
};

fn summarize(arena: Allocator, io: Io, paths: []const []const u8) !void {
    var suites: std.ArrayList(SuiteSummary) = .empty;
    for (paths) |path| {
        const bytes = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30)) catch |err| fail("{s}: {t}", .{ path, err });
        var failure: journal.Failure = .{};
        const j = journal.parseJournal(arena, bytes, &failure) catch |err| fail("{s}:{d}: {t}", .{ path, failure.line, err });
        for (j.tests) |t| {
            const s = try summaryFor(arena, &suites, t.suite, t.framework, t.version, t.suite_kind);
            s.counts.add(t);
            if (t.status == .FAIL or t.status.errored()) try s.failures.append(arena, t);
        }
        for (j.pages) |p| {
            const s = try summaryFor(arena, &suites, p.suite, p.framework, p.version, p.suite_kind);
            s.pages += 1;
            if (p.status == .OK) s.pages_ok += 1 else try s.page_problems.append(arena, try std.fmt.allocPrint(arena, "{s}: {t} ({s}) {s}", .{ p.page, p.status, p.exit, p.message orelse "" }));
        }
    }
    for (suites.items) |*s| {
        const c = s.counts;
        const ran = c.ran();
        const rate: f64 = if (ran == 0) 0 else 100.0 * @as(f64, @floatFromInt(c.pass)) / @as(f64, @floatFromInt(ran));
        std.debug.print("{s} {s} [{s}; {s}]: {d} pages ({d} OK); run {d}: passed {d}, failed {d} ({d:.1}% of run); errored {d}; excluded as rendering {d}; not run {d}; skipped by the project {d}\n", .{
            s.framework, s.version, s.suite, s.kind.label(), s.pages, s.pages_ok, ran, c.pass, c.fail, rate, c.errored(), c.rendering, c.not_run, c.project_skip,
        });
        for (s.page_problems.items) |p| std.debug.print("  page {s}\n", .{p});
        for (s.failures.items) |t| {
            const msg = t.message orelse "";
            const first = msg[0 .. std.mem.indexOfScalar(u8, msg, '\n') orelse msg.len];
            std.debug.print("  {t} {s} [{s}] {s}\n", .{ t.status, t.id, t.page, first[0..@min(first.len, 240)] });
        }
    }
}

fn summaryFor(arena: Allocator, suites: *std.ArrayList(SuiteSummary), suite: []const u8, framework: []const u8, version: []const u8, kind: journal.SuiteKind) !*SuiteSummary {
    for (suites.items) |*s| if (std.mem.eql(u8, s.suite, suite) and std.mem.eql(u8, s.version, version)) return s;
    try suites.append(arena, .{ .suite = suite, .framework = framework, .version = version, .kind = kind });
    return &suites.items[suites.items.len - 1];
}

/// Every journal.jsonl one or two directories below `dir`.
fn findJournals(arena: Allocator, io: Io, dir: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var d = try Io.Dir.cwd().openDir(io, dir, .{ .iterate = true });
    defer d.close(io);
    var walker = try d.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |e| {
        if (e.kind != .file or !std.mem.eql(u8, e.basename, "journal.jsonl")) continue;
        const depth = std.mem.count(u8, e.path, "/");
        if (depth < 1 or depth > 2) continue;
        try out.append(arena, try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, e.path }));
    }
    std.mem.sort([]const u8, out.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lt);
    return out.items;
}

fn writeReport(arena: Allocator, io: Io, m: manifest.Manifest, excluded_dir: []const u8, journals_dir: []const u8, out_dir: []const u8, o: report.Options) !void {
    var journals: std.ArrayList(journal.Journal) = .empty;
    for (try findJournals(arena, io, journals_dir)) |path| {
        const bytes = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 30)) catch |err| fail("{s}: {t}", .{ path, err });
        var failure: journal.Failure = .{};
        try journals.append(arena, journal.parseJournal(arena, bytes, &failure) catch |err| fail("{s}:{d}: {t}", .{ path, failure.line, err }));
    }
    var files: std.ArrayList([]const exclusions.Entry) = .empty;
    for (m.suites) |s| {
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ excluded_dir, s.excluded });
        const text = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(16 << 20)) catch |err| fail("{s}: {t}", .{ path, err });
        var pf: exclusions.ParseFailure = .{};
        const entries = exclusions.parse(arena, text, &pf) catch |err| fail("{s}:{d}: {t}", .{ path, pf.line, err });
        var fe: std.ArrayList(exclusions.Entry) = .empty;
        for (entries) |e| if (e.file) try fe.append(arena, e);
        try files.append(arena, fe.items);
    }
    const suites = try report.collect(arena, m, journals.items, files.items);
    try Io.Dir.cwd().createDirPath(io, out_dir);
    var index: Io.Writer.Allocating = .init(arena);
    try report.writeIndex(&index.writer, suites, o);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/index.html", .{out_dir}), .data = index.written() });
    var written: usize = 1;
    for (suites, 0..) |s, i| {
        var seen = false;
        for (suites[0..i]) |o2| if (std.mem.eql(u8, o2.suite.framework, s.suite.framework)) {
            seen = true;
        };
        if (seen) continue;
        const dir = try std.fmt.allocPrint(arena, "{s}/{s}", .{ out_dir, s.suite.framework });
        try Io.Dir.cwd().createDirPath(io, dir);
        var page: Io.Writer.Allocating = .init(arena);
        try report.writeSuites(&page.writer, s.suite.framework, suites, o);
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/index.html", .{dir}), .data = page.written() });
        written += 1;
    }
    std.debug.print("fw_matrix: report: {d} journal(s), {d} page(s) written to {s}\n", .{ journals.items.len, written, out_dir });
}

test {
    _ = report;
    _ = journal;
    _ = exclusions;
    _ = manifest;
    _ = readers;
    _ = generated;
    _ = server;
    _ = fetch;
    _ = run;
}
