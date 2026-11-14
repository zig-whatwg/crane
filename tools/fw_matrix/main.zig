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
//!       (`--suite=todomvc`: every TodoMVC app, here and in `run`)
//!       every pinned file downloaded and checked by sha256 into <dir>
//!       (~/crane-frameworks on the run host), the trees made
//!   fw_matrix run --frameworks-dir=<dir> --console=<repl> --crane-commit=<sha>
//!                 --label=<l> --out=<dir> [--generation=<n>] [--suite=<id>,...]
//!                 [--pages=<id>,...] [--parallel=<n>] [--no-exclusions]
//!                 [--stop-file=<f>]
//!       each suite's pages in a fresh console per page; <out>/journal.jsonl
//!       (crane-fw/1) and <out>/console/<suite>-<page>.{out,err}
//!   fw_matrix run --browser=<name> --console=<headless Chrome> ...
//!       the comparison column: the same pages in headless Chrome, read from
//!       QUnit's TAP on its console (an in-page QUnit suite with TAP on: the
//!       TodoMVC port); every record names the browser
//!   fw_matrix summary <journal.jsonl> ...
//!       per suite: pages, tests run / passed / failed / errored / excluded
//!       as rendering / not run; every failure with its first assertion
//!   fw_matrix report --journals=<dir> --out=<dir> [--assets=<url>]
//!       the matrix page and a page per framework, from every journal.jsonl
//!       one or two levels below <dir> (report.zig); --assets is where the
//!       WPT site's site.css is, relative to <out> (default "../")
//!   fw_matrix import --reader=jtr|wtr-summary --suite=<id> --log=<file>
//!                 --label=<l> --browser=<name> --browser-sha256=<hex>
//!                 --runner=<text> --date=<YYYY-MM-DD> --out=<dir> [--page=<id>]
//!       a browser's run by the project's own runner, read from that
//!       runner's log into <out>/journal.jsonl (crane-fw/1), every record
//!       naming the browser and the log: jquery-test-runner's console log
//!       (one page, --page names it), or Bazel's web-test-runner lines (a
//!       page per target, matched to the suite's pages by their targets)
//!   fw_matrix serve --frameworks-dir=<dir> --suite=<id> [--port=<n>]
//!       a suite's tree alone, for a person to open in a browser (the
//!       project's own server when the manifest names one)
//!
//! A tool: std only, on the host (tools/AGENTS.md "Tools are Zig"); nothing
//! of Crane's engine. Node runs only where a suite's manifest entry names it
//! (the user, 2026-11-11 17:43 ET: "we can run node for the purposes of these
//! tests"): `fetch` installs the project's own dependencies with it and runs
//! its own build scripts, and `run` and `serve` start the project's own test
//! server under it. Crane itself is never driven from Node.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const journal = @import("journal.zig");
pub const exclusions = @import("exclusions.zig");
pub const manifest = @import("manifest.zig");
pub const readers = @import("readers.zig");
pub const generated = @import("generated.zig");
pub const server = @import("server.zig");
pub const external = @import("external.zig");
pub const fetch = @import("fetch.zig");
pub const run = @import("run.zig");
pub const report = @import("report.zig");

const usage =
    \\usage: fw_matrix check|fetch|run|summary|report|import|serve [options]
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
        // Every app's pin is checked before the fetch fails on one, so one
        // fetch names every app whose build is not the pinned one.
        var mismatched: usize = 0;
        for (try selectSuites(arena, m, try args.list(arena, "suite"))) |s| fetch.fetchSuite(gpa, io, dir, s, init.environ_map) catch |err| switch (err) {
            error.AppMismatch, error.AppMissing => mismatched += 1,
            else => return err,
        };
        if (mismatched > 0) fail("{d} TodoMVC app(s) are not the pinned build (each named above)", .{mismatched});
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
            // A browser's run for the comparison column has no Crane commit.
            .crane_commit = if (args.get("browser") != null) "none" else args.need("crane-commit"),
            .label = args.need("label"),
            .generation = generation,
            .out_dir = args.need("out"),
            .pages = try args.list(arena, "pages"),
            .no_exclusions = args.has("no-exclusions"),
            .parallel = parallel,
            .stop_file = args.get("stop-file"),
            .environ = init.environ_map,
            .browser = args.get("browser"),
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
    } else if (std.mem.eql(u8, cmd, "import")) {
        const m = try loadManifest(gpa, arena, io, args.get("manifest") orelse default_manifest);
        const s = manifest.find(m, args.need("suite")) orelse fail("no suite {s} in the manifest", .{args.need("suite")});
        const log_path = args.need("log");
        const log = Io.Dir.cwd().readFileAlloc(io, log_path, arena, .limited(256 << 20)) catch |err| fail("{s}: {t}", .{ log_path, err });
        const reader = args.need("reader");
        const one_page = try arena.alloc(readers.LogPage, 1);
        const pages: []const readers.LogPage = if (std.mem.eql(u8, reader, "jtr")) blk: {
            one_page[0] = readers.parseJtrLog(arena, log) catch fail("{s}: not a jquery-test-runner log this reader knows", .{log_path});
            break :blk one_page;
        } else if (std.mem.eql(u8, reader, "wtr-summary"))
            readers.parseWtrSummary(arena, log) catch fail("{s}: no Bazel web-test-runner lines this reader knows", .{log_path})
        else
            fail("--reader={s}: jtr or wtr-summary", .{reader});
        const log_sha = fetch.sha256Hex(log);
        const text = importRecords(arena, s, .{
            .label = args.need("label"),
            .browser = args.need("browser"),
            .browser_sha256 = args.need("browser-sha256"),
            .runner = args.need("runner"),
            .log = log_path,
            .log_sha256 = &log_sha,
            .date = args.need("date"),
            .page = args.get("page"),
        }, pages) catch |err| fail("import: {t}", .{err});
        const out_dir = args.need("out");
        try Io.Dir.cwd().createDirPath(io, out_dir);
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/journal.jsonl", .{out_dir}), .data = text });
        std.debug.print("fw_matrix: import: {d} page(s) of {s} from {s} into {s}/journal.jsonl\n", .{ pages.len, s.id, log_path, out_dir });
    } else if (std.mem.eql(u8, cmd, "serve")) {
        const m = try loadManifest(gpa, arena, io, args.get("manifest") orelse default_manifest);
        const s = manifest.find(m, args.need("suite")) orelse fail("no suite {s} in the manifest", .{args.need("suite")});
        const root = try std.fmt.allocPrint(arena, "{s}/{s}", .{ args.need("frameworks-dir"), try manifest.treeName(arena, s) });
        const port: u16 = if (args.get("port")) |p| std.fmt.parseInt(u16, p, 10) catch fail("--port={s}", .{p}) else 8000;
        if (s.server) |es| if (manifest.serverPerPage(es)) {
            fail("serve: each page of {s} starts its own server (its Bazel target); run one page with `fw_matrix run --suite={s} --pages=<id>`", .{ s.id, s.id });
        };
        if (s.server) |es| {
            // The project's own server, as a run starts it.
            const node_dir = try fetch.nodeDirChecked(arena, io, args.need("frameworks-dir"), s.node.?);
            const tree_abs = try Io.Dir.cwd().realPathFileAlloc(io, root, arena);
            const env = try arena.create(std.process.Environ.Map);
            env.* = try fetch.nodeEnviron(arena, init.environ_map, try std.fmt.allocPrint(arena, "{s}/bin", .{node_dir}), try std.fmt.allocPrint(arena, "{s}/downloads/npm-cache", .{try Io.Dir.cwd().realPathFileAlloc(io, args.need("frameworks-dir"), arena)}));
            const log = try std.fmt.allocPrint(arena, "{s}-serve.log", .{tree_abs});
            const srv = try external.External.start(gpa, io, .{ .argv = es.argv, .cwd = tree_abs, .environ = env, .ready_path = es.ready_path, .ready_ms = @as(u64, es.ready_s) * 1000, .port = port, .log_path = log });
            defer srv.stop();
            std.debug.print("fw_matrix: {s} ({s}, pid {d}) serving {s} on http://{s}:{d}/ (its output: {s}; Ctrl+C ends)\n", .{ es.name, s.id, srv.pid, root, es.host, srv.port(), log });
            while (true) Io.sleep(io, .fromSeconds(3600), .awake) catch {};
        }
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

/// The suites `--suite` names; "todomvc" names every TodoMVC app.
fn selectSuites(arena: Allocator, m: manifest.Manifest, only: ?[]const []const u8) ![]const manifest.Suite {
    const ids = only orelse return m.suites;
    var out: std.ArrayList(manifest.Suite) = .empty;
    for (ids) |id| {
        if (std.mem.eql(u8, id, "todomvc")) {
            for (m.suites) |s| if (s.kind == .todomvc_port) try out.append(arena, s);
            continue;
        }
        try out.append(arena, manifest.find(m, id) orelse fail("no suite {s} in the manifest", .{id}));
    }
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
    try report.writeIndex(arena, &index.writer, m, suites, o);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/index.html", .{out_dir}), .data = index.written() });
    var written: usize = 1;
    // A page per framework of the first section (or, in a manifest without
    // that list, per framework a project suite names).
    var frameworks: std.ArrayList(manifest.Framework) = .empty;
    try frameworks.appendSlice(arena, m.frameworks);
    if (m.frameworks.len == 0) for (m.suites) |s| {
        if (s.kind != .project) continue;
        for (frameworks.items) |fw| {
            if (std.mem.eql(u8, fw.id, s.framework)) break;
        } else try frameworks.append(arena, .{ .id = s.framework, .title = s.title });
    };
    for (frameworks.items) |fw| {
        var page: Io.Writer.Allocating = .init(arena);
        try report.writeFramework(arena, &page.writer, m, fw, suites, o);
        try writePage(io, arena, out_dir, "", fw.id, page.written());
        written += 1;
    }
    for (suites) |s| if (s.suite.kind == .todomvc_port) {
        var page: Io.Writer.Allocating = .init(arena);
        try report.writeApp(arena, &page.writer, m, s, o);
        const dir = report.pageDir(s.suite);
        try writePage(io, arena, out_dir, dir[0], dir[1], page.written());
        written += 1;
    };
    std.debug.print("fw_matrix: report: {d} journal(s), {d} page(s) written to {s}\n", .{ journals.items.len, written, out_dir });
}

pub const ImportOptions = struct {
    label: []const u8,
    browser: []const u8,
    browser_sha256: []const u8,
    runner: []const u8,
    log: []const u8,
    log_sha256: []const u8,
    date: []const u8,
    /// The page id a one-page log is recorded as; null: each log page is
    /// matched to the suite's page by its Bazel target.
    page: ?[]const u8 = null,
};

pub const ImportError = error{ OutOfMemory, WriteFailed, UnknownTarget, BadPage, BadSha256, BadDate };

/// The suite's page a Bazel target of the browser's run is: rules_browsers'
/// wtr_test(name = X) makes X_debug (the manual-mode page Crane opens, the
/// page's `target`) and X_chromium (the run in its Chromium).
fn pageForTarget(s: manifest.Suite, label: []const u8) ?[]const u8 {
    const suffix = "_chromium";
    if (!std.mem.endsWith(u8, label, suffix)) return null;
    const base = label[0 .. label.len - suffix.len];
    for (s.pages) |p| if (p.target) |t| {
        if (std.mem.endsWith(u8, t, "_debug") and std.mem.eql(u8, t[0 .. t.len - "_debug".len], base)) return p.id;
    };
    return null;
}

/// A browser's run, read from its runner's log, as journal lines: a page
/// record per log page (its counts, the failures it does not name as
/// unnamed), a test record per failure it names.
pub fn importRecords(arena: Allocator, s: manifest.Suite, o: ImportOptions, pages: []const readers.LogPage) ImportError![]const u8 {
    if (!journal.isSha256(o.browser_sha256) or !journal.isSha256(o.log_sha256)) return error.BadSha256;
    if (!journal.isDate(o.date)) return error.BadDate;
    if (o.page != null and pages.len != 1) return error.BadPage;
    var out: Io.Writer.Allocating = .init(arena);
    const imported: journal.Imported = .{ .runner = o.runner, .log = o.log, .log_sha256 = o.log_sha256, .date = o.date };
    for (pages) |lp| {
        const page_id = o.page orelse pageForTarget(s, lp.where) orelse return error.UnknownTarget;
        const named: u32 = @intCast(lp.failures.len);
        for (lp.failures) |f| try journal.writeTest(&out.writer, .{
            .label = o.label,
            .crane_commit = "none",
            .console_sha256 = o.browser_sha256,
            .framework = s.framework,
            .version = s.version,
            .suite = s.id,
            .suite_kind = s.kind,
            .source_sha256 = s.source.sha256,
            .page = page_id,
            .module = f.module,
            .name = f.name,
            .id = f.id,
            .status = .FAIL,
            .message = f.message,
            .browser = o.browser,
        });
        // A target its runner failed with no failing test: its errors were
        // outside any test (zone.js's browser_test in Chrome).
        const failed_outside = lp.runner_status != null and std.mem.eql(u8, lp.runner_status.?, "FAILED") and lp.failed == 0;
        try journal.writePage(&out.writer, .{
            .label = o.label,
            .crane_commit = "none",
            .console_sha256 = o.browser_sha256,
            .framework = s.framework,
            .version = s.version,
            .suite = s.id,
            .suite_kind = s.kind,
            .source_sha256 = s.source.sha256,
            .page = page_id,
            .url = lp.where,
            .status = if (failed_outside) .ERROR else .OK,
            .message = if (failed_outside) try std.fmt.allocPrint(arena, "the runner reported the page FAILED with no failing test ({d} passed, 0 failed, {d} skipped)", .{ lp.passed, lp.skipped }) else null,
            .wall_ms = lp.wall_ms,
            .reported_total = lp.passed + lp.failed,
            .reported_failed = lp.failed,
            .ran = named,
            .records = named,
            .unnamed_passed = lp.passed,
            .unnamed_failed = if (lp.failed > named) lp.failed - named else null,
            .unnamed_pending = if (lp.skipped > 0) lp.skipped else null,
            .exit = if (lp.runner_status) |w| try std.fmt.allocPrint(arena, "the runner's word for the page: {s}", .{w}) else "read from the runner's log",
            .browser = o.browser,
            .imported = imported,
        });
    }
    return out.written();
}

/// <out>/<prefix><name>/index.html.
fn writePage(io: Io, arena: Allocator, out_dir: []const u8, prefix: []const u8, name: []const u8, data: []const u8) !void {
    const dir = try std.fmt.allocPrint(arena, "{s}/{s}{s}", .{ out_dir, prefix, name });
    try Io.Dir.cwd().createDirPath(io, dir);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/index.html", .{dir}), .data = data });
}

test "import: a runner's log as a browser's journal - named failures as test records, the rest as counts, pages by target" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const sha: [64]u8 = @splat('a');
    const suite: manifest.Suite = .{ .id = "angular-jasmine", .framework = "angular", .title = "Angular", .version = "22.2.6", .kind = .project, .repository = "https://github.com/angular/angular", .tag = "v22.2.6", .commit = "c", .licence = "MIT", .runner = "Jasmine", .reader = .jasmine_console, .source = .{ .url = "https://x", .sha256 = &sha }, .pages = &.{
        .{ .id = "core-test-acceptance-acceptance", .path = "?a", .target = "//packages/core/test/acceptance:acceptance_web_debug" },
        .{ .id = "zone-test-browser", .path = "?b", .target = "//packages/zone.js/test:browser_test_debug" },
    }, .excluded = "x.txt" };
    const o: ImportOptions = .{ .label = "chrome-ng", .browser = "Chrome for Testing headless shell 159.0.8154.2", .browser_sha256 = &sha, .runner = "bazel test <target>_chromium", .log = "tmp/ng.log", .log_sha256 = &sha, .date = "2026-11-14" };
    const pages = [_]readers.LogPage{
        .{ .where = "//packages/core/test/acceptance:acceptance_web_chromium", .runner_status = "FAILED", .passed = 2777, .failed = 1, .skipped = 4, .wall_ms = 15_200 },
        .{ .where = "//packages/zone.js/test:browser_test_chromium", .runner_status = "FAILED", .passed = 513, .failed = 0, .skipped = 24 },
    };
    const text = try importRecords(a, suite, o, &pages);
    var failure: journal.Failure = .{};
    const j = try journal.parseJournal(a, text, &failure);
    try std.testing.expectEqual(@as(usize, 0), j.tests.len);
    try std.testing.expectEqual(@as(usize, 2), j.pages.len);
    const p0 = j.pages[0];
    try std.testing.expectEqualStrings("core-test-acceptance-acceptance", p0.page);
    try std.testing.expectEqual(journal.PageStatus.OK, p0.status);
    try std.testing.expectEqual(@as(?u32, 2777), p0.unnamed_passed);
    try std.testing.expectEqual(@as(?u32, 1), p0.unnamed_failed);
    try std.testing.expectEqual(@as(?u32, 4), p0.unnamed_pending);
    try std.testing.expectEqualStrings("Chrome for Testing headless shell 159.0.8154.2", p0.browser.?);
    try std.testing.expectEqualStrings("2026-11-14", p0.imported.?.date);
    try std.testing.expectEqualStrings("none", p0.crane_commit);
    // Failed by its runner with no failing test: an error outside the tests.
    try std.testing.expectEqual(journal.PageStatus.ERROR, j.pages[1].status);
    try std.testing.expectEqualStrings("zone-test-browser", j.pages[1].page);

    // jtr: one page, named failures as test records.
    var one = o;
    one.page = "test";
    const failures = [_]readers.Reported{.{ .module = "core", .name = "parseXML", .id = "core: parseXML", .status = .FAIL, .message = "expected 11" }};
    const jt = try journal.parseJournal(a, try importRecords(a, suite, one, &.{.{ .where = "http://localhost:1/test/", .passed = 1144, .failed = 1, .skipped = 0, .failures = &failures }}), &failure);
    try std.testing.expectEqual(@as(usize, 1), jt.tests.len);
    try std.testing.expectEqualStrings("core: parseXML", jt.tests[0].id);
    try std.testing.expectEqualStrings("expected 11", jt.tests[0].message.?);
    try std.testing.expectEqual(@as(?u32, null), jt.pages[0].unnamed_failed);
    // A target the suite has no page for, a bad hash or date: refused.
    try std.testing.expectError(error.UnknownTarget, importRecords(a, suite, o, &.{.{ .where = "//x:y_chromium", .passed = 1, .failed = 0, .skipped = 0 }}));
    var bad = o;
    bad.date = "Nov 14";
    try std.testing.expectError(error.BadDate, importRecords(a, suite, bad, &pages));
}

test {
    _ = report;
    _ = journal;
    _ = exclusions;
    _ = manifest;
    _ = readers;
    _ = generated;
    _ = server;
    _ = external;
    _ = fetch;
    _ = run;
}
