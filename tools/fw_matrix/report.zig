//! `fw_matrix report`: the JS framework compatibility matrix as finished
//! HTML, from journals only (tmp/plans/framework-matrix-plan.md, section 4):
//!
//!   <out>/index.html               the matrix: a row per framework
//!   <out>/<framework>/index.html   its suites: every page, every failing
//!                                  test with its message, every excluded or
//!                                  not-run test with its reason
//!
//! The site's rules (tools/wpt_site/DESIGN.md, PRODUCT.md): the content is in
//! the HTML (no script), graphs count tests, red is a failure, grey is
//! excluded or not run; it uses the WPT site's stylesheet and its HTML
//! helpers (tools/wpt_site/html.zig, by import). Every page says that
//! rendering tests are not run. A row never lets a reader take Crane's port
//! of an app spec for the project's own suite: each suite names its kind.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const W = *Io.Writer;
const html = @import("site_html");
const journal = @import("journal.zig");
const manifest = @import("manifest.zig");
const exclusions = @import("exclusions.zig");

pub const Options = struct {
    /// Where the WPT site's site.css is, relative to <out>/ ("../").
    assets: []const u8 = "../",
};

/// One run of one suite: its records.
pub const Run = struct {
    label: []const u8,
    generation: ?u32,
    crane_commit: []const u8,
    console_sha256: []const u8,
    tests: []const journal.TestRecord,
    pages: []const journal.PageRecord,
    counts: journal.Counts,
};

pub const SuiteRuns = struct {
    suite: manifest.Suite,
    /// Oldest first; the last is the one shown.
    runs: []const Run,
    /// The `[file:...]` entries of its exclusion list (not in a journal).
    file_entries: []const exclusions.Entry,
};

/// The rows a framework without a runnable suite yet shows (the user,
/// 2026-11-11 09:57 ET: React, Vue, Svelte and Angular are measured by the
/// prebuilt TodoMVC app against Crane's port of TodoMVC's shared app spec;
/// tmp/plans/framework-suites-research.md A.2).
pub const Pending = struct {
    framework: []const u8,
    title: []const u8,
    own_suite: []const u8,
    planned: []const u8,
};

pub const pending = [_]Pending{
    .{ .framework = "react", .title = "React", .own_suite = "React's own tests run under Node: Jest with jsdom; its browser-run tests (react-devtools-inline, fixtures/flight, the compiler playground) assert from Node through Playwright.", .planned = "the prebuilt TodoMVC app (tastejs/todomvc, React 19.2.5) against Crane's port of TodoMVC's shared app spec (29 tests)" },
    .{ .framework = "vue", .title = "Vue", .own_suite = "Vue's own tests run under Node: Vitest with jsdom; its e2e tests (36) assert from Node through Puppeteer, and its browser-mode Transition tests are compiled and driven by Vite.", .planned = "the prebuilt TodoMVC app (tastejs/todomvc, Vue 3.5.33) against Crane's port of TodoMVC's shared app spec (29 tests)" },
    .{ .framework = "angular", .title = "Angular", .own_suite = "Angular's browser suites are TypeScript bundled by Bazel and esbuild and run by Karma or web-test-runner, all Node.", .planned = "the prebuilt TodoMVC app (tastejs/todomvc, Angular 21.2.11) against Crane's port of TodoMVC's shared app spec (29 tests)" },
    .{ .framework = "svelte", .title = "Svelte", .own_suite = "Svelte's runtime-browser samples (75) are compiled by the Svelte compiler and driven by Playwright from Node; its other suites run under jsdom.", .planned = "the prebuilt TodoMVC app (tastejs/todomvc, Svelte 5.55.5) against Crane's port of TodoMVC's shared app spec (29 tests)" },
};

pub const statement =
    "Crane draws nothing: tests whose result depends on layout geometry or pixels are not run, and each is listed with its reason. Computed style, events, timers and animations are run. Tests that need a project's Node tooling or its own test server are not run either, and are listed with theirs.";

/// The runs in `journals` grouped by suite, each suite's runs ordered by
/// generation (lane runs, with none, after) then label.
pub fn collect(arena: Allocator, m: manifest.Manifest, journals: []const journal.Journal, file_entries: []const []const exclusions.Entry) ![]SuiteRuns {
    var out: std.ArrayList(SuiteRuns) = .empty;
    for (m.suites, 0..) |s, si| {
        var runs: std.ArrayList(Run) = .empty;
        for (journals) |j| {
            var labels: std.ArrayList([]const u8) = .empty;
            for (j.pages) |p| if (std.mem.eql(u8, p.suite, s.id) and std.mem.eql(u8, p.version, s.version)) {
                for (labels.items) |l| {
                    if (std.mem.eql(u8, l, p.label)) break;
                } else try labels.append(arena, p.label);
            };
            for (labels.items) |label| {
                var tests: std.ArrayList(journal.TestRecord) = .empty;
                var pages: std.ArrayList(journal.PageRecord) = .empty;
                var counts: journal.Counts = .{};
                for (j.tests) |t| if (std.mem.eql(u8, t.suite, s.id) and std.mem.eql(u8, t.label, label)) {
                    try tests.append(arena, t);
                    counts.add(t);
                };
                for (j.pages) |p| if (std.mem.eql(u8, p.suite, s.id) and std.mem.eql(u8, p.label, label)) try pages.append(arena, p);
                const first = pages.items[0];
                try runs.append(arena, .{ .label = label, .generation = first.generation, .crane_commit = first.crane_commit, .console_sha256 = first.console_sha256, .tests = tests.items, .pages = pages.items, .counts = counts });
            }
        }
        std.mem.sort(Run, runs.items, {}, struct {
            fn lt(_: void, a: Run, b: Run) bool {
                const ga = a.generation orelse std.math.maxInt(u32);
                const gb = b.generation orelse std.math.maxInt(u32);
                if (ga != gb) return ga < gb;
                return std.mem.order(u8, a.label, b.label) == .lt;
            }
        }.lt);
        try out.append(arena, .{ .suite = s, .runs = runs.items, .file_entries = if (si < file_entries.len) file_entries[si] else &.{} });
    }
    return out.items;
}

fn rate(w: W, pass: u32, ran: u32) !void {
    if (ran == 0) return w.writeAll("&mdash;");
    const tenths = (@as(u64, pass) * 1000 + ran / 2) / ran;
    try w.print("{d}.{d}%", .{ tenths / 10, tenths % 10 });
}

/// A stacked bar of one run's tests: passed (green), failed and errored
/// (red), excluded and not run (grey), each a share of all its tests.
fn meter(w: W, c: journal.Counts) !void {
    const parts = [_]struct { u32, []const u8, []const u8 }{
        .{ c.pass, "var(--pass)", "passed" },
        .{ c.fail + c.errored(), "var(--fail)", "failed or errored" },
        .{ c.rendering + c.not_run + c.project_skip, "var(--block-seg)", "excluded or not run" },
    };
    var total: u64 = 0;
    for (parts) |p| total += p[0];
    if (total == 0) return;
    try w.writeAll("<div class=\"meter\" role=\"img\" aria-label=\"");
    for (parts, 0..) |p, i| {
        if (i > 0) try w.writeAll(", ");
        try html.num(w, p[0]);
        try w.print(" {s}", .{p[2]});
    }
    try w.writeAll("\">");
    for (parts) |p| if (p[0] > 0) try w.print("<span style=\"width:{d:.3}%;background:{s}\"></span>", .{ 100.0 * @as(f64, @floatFromInt(p[0])) / @as(f64, @floatFromInt(total)), p[1] });
    try w.writeAll("</div>");
}

/// Passed tests per run, oldest first, as a small line (graphs count tests).
fn sparkline(w: W, runs: []const Run) !void {
    if (runs.len < 2) return w.writeAll("<span class=\"n\">first run</span>");
    var max: u32 = 1;
    for (runs) |r| max = @max(max, r.counts.pass);
    const width: f64 = 96;
    const height: f64 = 20;
    try w.writeAll("<svg class=\"spark\" viewBox=\"0 0 96 20\" width=\"96\" height=\"20\" role=\"img\" aria-label=\"passed tests per run: ");
    for (runs, 0..) |r, i| {
        if (i > 0) try w.writeAll(", ");
        try html.num(w, r.counts.pass);
    }
    try w.writeAll("\"><polyline fill=\"none\" stroke=\"var(--pass)\" stroke-width=\"1.5\" points=\"");
    for (runs, 0..) |r, i| {
        const x = width * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(runs.len - 1));
        const y = height - 2 - (height - 4) * @as(f64, @floatFromInt(r.counts.pass)) / @as(f64, @floatFromInt(max));
        try w.print("{d:.1},{d:.1} ", .{ x, y });
    }
    try w.writeAll("\"/></svg>");
}

fn head(w: W, title: []const u8, description: []const u8, o: Options, depth: u32) !void {
    try w.writeAll("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n<title>");
    try html.text(w, title);
    try w.writeAll("</title>\n<meta name=\"description\" content=\"");
    try html.text(w, description);
    try w.writeAll("\">\n<meta name=\"color-scheme\" content=\"light dark\">\n<link rel=\"stylesheet\" href=\"");
    for (0..depth) |_| try w.writeAll("../");
    try w.print("{s}site.css\">\n<link rel=\"icon\" href=\"data:,\">\n", .{o.assets});
    try w.writeAll(style);
    try w.writeAll("</head>\n<body>\n<main class=\"doc fw\" id=\"main\">\n");
}

const style =
    \\<style>
    \\.fw h2 { margin-top: 2.2rem; }
    \\.fw .fail { color: var(--fail); }
    \\.fw .grey { color: var(--ink-2); }
    \\.fw .listing tbody th { width: auto; }
    \\.fw .listing td.msg pre { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; font: 400 0.78rem/1.45 var(--mono); }
    \\.fw .meter { margin: 0.3rem 0 0; min-width: 8rem; }
    \\.fw .kind { display: block; font: 400 0.82rem/1.35 var(--sans); color: var(--ink-2); }
    \\.fw .pending td, .fw .pending th { color: var(--ink-2); }
    \\</style>
    \\
;

fn statementNote(w: W) !void {
    try w.writeAll("<div class=\"note\"><p><span class=\"note-label\">Not run: rendering.</span> ");
    try html.text(w, statement);
    try w.writeAll("</p></div>\n");
}

fn latest(s: SuiteRuns) ?Run {
    return if (s.runs.len == 0) null else s.runs[s.runs.len - 1];
}

/// "the project's own browser suite (test/index.html, QUnit 2.24.2, 23 pages)".
fn suiteLabel(w: W, s: manifest.Suite) !void {
    try html.text(w, s.title);
    try w.writeByte(' ');
    try html.text(w, s.version);
    try w.writeAll(" &mdash; ");
    try html.text(w, journal.SuiteKind.label(s.kind));
    try w.writeAll(" (");
    try html.text(w, s.runner);
    try w.print(", {d} page{s})", .{ s.pages.len, if (s.pages.len == 1) "" else "s" });
}

pub fn writeIndex(w: W, suites: []const SuiteRuns, o: Options) !void {
    try head(w, "Crane: JS framework compatibility matrix", "The JavaScript frameworks' own browser test suites run in Crane, with rendering tests excluded and named.", o, 0);
    try w.writeAll("<header class=\"head\">\n<h1>Crane <span class=\"h1-rest\">JS framework compatibility matrix</span></h1>\n<p class=\"subtitle\">Each framework's own browser tests, opened in Crane's console as a user opens a page, and read from the framework's own report. No Node runs at any step.</p>\n</header>\n");
    try statementNote(w);
    try w.writeAll("<h2>The matrix</h2>\n<table class=\"listing\">\n<thead><tr><th>Framework</th><th class=\"n\">Run</th><th class=\"n\">Passed</th><th class=\"n\">Failed</th><th class=\"n\">Errored</th><th class=\"n\">Excluded: rendering</th><th class=\"n\">Not run</th><th class=\"n\">Pass rate</th><th>History</th></tr></thead>\n<tbody>\n");
    for (suites) |s| {
        try w.writeAll("<tr><th><a href=\"");
        try html.text(w, s.suite.framework);
        try w.writeAll("/\">");
        try html.text(w, s.suite.title);
        try w.writeAll("</a><span class=\"kind\">");
        try suiteLabel(w, s.suite);
        try w.writeAll("</span>");
        if (latest(s)) |r| try meter(w, r.counts);
        try w.writeAll("</th>");
        if (latest(s)) |r| {
            const c = r.counts;
            try w.print("<td class=\"n\">{d}</td><td class=\"n\">{d}</td><td class=\"n{s}\">{d}</td><td class=\"n{s}\">{d}</td><td class=\"n grey\">{d}</td><td class=\"n grey\">{d}</td><td class=\"n\">", .{
                c.ran(), c.pass, if (c.fail > 0) " fail" else "", c.fail, if (c.errored() > 0) " fail" else "", c.errored(), c.rendering, c.not_run + c.project_skip + @as(u32, @intCast(s.file_entries.len)),
            });
            try rate(w, c.pass, c.ran());
            try w.writeAll("</td><td>");
            try sparkline(w, s.runs);
            try w.writeAll("</td></tr>\n");
        } else try w.writeAll("<td class=\"n\" colspan=\"8\">no run yet</td></tr>\n");
    }
    for (pending) |p| {
        try w.writeAll("<tr class=\"pending\"><th>");
        try html.text(w, p.title);
        try w.writeAll("<span class=\"kind\">Not run yet: ");
        try html.text(w, p.own_suite);
        try w.writeAll(" This row will run ");
        try html.text(w, p.planned);
        try w.writeAll(".</span></th><td class=\"n\" colspan=\"8\">&mdash;</td></tr>\n");
    }
    try w.writeAll("</tbody>\n</table>\n");
    try w.writeAll("<p class=\"grey\">Pass rate is passed over run. Errored: due to run and never reported (the page's time ran out, or the console ended). Not run: tests needing the project's test server or its Node build, files only its Node runner loads, and tests the project itself skips.</p>\n");
    try w.writeAll("<footer class=\"foot\"><p>Written as HTML by <code>tools/fw_matrix</code> from its journals (<code>crane-fw/1</code>).</p></footer>\n</main>\n</body>\n</html>\n");
}

fn statusText(s: journal.Status) []const u8 {
    return switch (s) {
        .PASS => "pass",
        .FAIL => "fail",
        .TIMEOUT => "timeout",
        .CRASH => "crash",
        .NOTRUN => "not run",
    };
}

pub fn writeSuites(w: W, framework: []const u8, suites: []const SuiteRuns, o: Options) !void {
    var title_buf: [128]u8 = undefined;
    var title: []const u8 = framework;
    for (suites) |s| if (std.mem.eql(u8, s.suite.framework, framework)) {
        title = std.fmt.bufPrint(&title_buf, "Crane: {s} in the JS framework matrix", .{s.suite.title}) catch title;
        break;
    };
    try head(w, title, "A framework's browser test suites run in Crane: every failure with its message, every excluded test with its reason.", o, 1);
    for (suites) |s| {
        if (!std.mem.eql(u8, s.suite.framework, framework)) continue;
        try w.writeAll("<header class=\"head\">\n<h1>");
        try html.text(w, s.suite.title);
        try w.writeAll(" <span class=\"h1-rest\">in Crane</span></h1>\n<p class=\"subtitle\">");
        try suiteLabel(w, s.suite);
        try w.writeAll(". <a href=\"../\">The matrix</a>.</p>\n</header>\n");
        try statementNote(w);
        const r = latest(s) orelse {
            try w.writeAll("<p>No run yet.</p>\n");
            continue;
        };
        try w.writeAll("<h2>The run</h2>\n<p>");
        try html.text(w, s.suite.repository);
        try w.writeAll(" at ");
        try html.text(w, s.suite.tag);
        try w.writeAll(" (<code>");
        try html.text(w, s.suite.commit[0..@min(12, s.suite.commit.len)]);
        try w.writeAll("</code>), run by Crane ");
        if (r.generation) |g| try w.print("of generation {d} ", .{g});
        try w.writeAll("<code>");
        try html.text(w, r.crane_commit);
        try w.writeAll("</code> (console sha256 <code>");
        try html.text(w, r.console_sha256[0..16]);
        try w.writeAll("&hellip;</code>), run <code>");
        try html.text(w, r.label);
        try w.writeAll("</code>.</p>\n");
        try meter(w, r.counts);

        try w.writeAll("<table class=\"listing\">\n<thead><tr><th>Page</th><th>Outcome</th><th class=\"n\">Run</th><th class=\"n\">Failed</th><th class=\"n\">Excluded</th><th class=\"n\">Not run</th><th class=\"n\">Seconds</th></tr></thead>\n<tbody>\n");
        for (r.pages) |p| {
            var c: journal.Counts = .{};
            for (r.tests) |t| if (std.mem.eql(u8, t.page, p.page)) c.add(t);
            try w.writeAll("<tr><th><code>");
            try html.text(w, p.page);
            try w.print("</code></th><td{s}>{t}", .{ if (p.status == .OK) "" else " class=\"fail\"", p.status });
            if (p.message) |m| {
                try w.writeAll(": ");
                try html.text(w, m[0..@min(m.len, 300)]);
            }
            try w.print("</td><td class=\"n\">{d}</td><td class=\"n{s}\">{d}</td><td class=\"n grey\">{d}</td><td class=\"n grey\">{d}</td><td class=\"n\">{d}</td></tr>\n", .{ c.ran(), if (c.fail + c.errored() > 0) " fail" else "", c.fail + c.errored(), c.rendering, c.not_run + c.project_skip, p.wall_ms / 1000 });
        }
        try w.writeAll("</tbody>\n</table>\n");

        try section(w, r, "Failed and errored", .failed);
        try section(w, r, "Excluded: rendering", .rendering);
        try section(w, r, "Not run", .not_run);
        if (s.file_entries.len > 0) {
            try w.writeAll("<h3>Files not run</h3>\n<table class=\"listing\">\n<tbody>\n");
            for (s.file_entries) |e| {
                try w.writeAll("<tr><th><code>");
                try html.text(w, e.id);
                try w.writeAll("</code></th><td>");
                try html.text(w, e.why);
                try w.writeAll("</td></tr>\n");
            }
            try w.writeAll("</tbody>\n</table>\n");
        }
        try section(w, r, "Skipped by the project", .project_skip);

        var any_loaded = false;
        for (r.pages) |p| for (p.loaded) |l| {
            if (!any_loaded) try w.writeAll("<h2>Loaded from other origins</h2>\n<p>The project's page loads these itself; a run depends on that origin being reachable.</p>\n<ul>\n");
            any_loaded = true;
            try w.writeAll("<li><code>");
            try html.text(w, l.url);
            try w.writeAll("</code>");
            if (l.sha256) |h| {
                try w.writeAll(" (sha256 <code>");
                try html.text(w, h[0..16]);
                try w.writeAll("&hellip;</code>, checked by the harness before the run)");
            }
            try w.writeAll("</li>\n");
        };
        if (any_loaded) try w.writeAll("</ul>\n");
    }
    try w.writeAll("<footer class=\"foot\"><p>Written as HTML by <code>tools/fw_matrix</code> from its journals (<code>crane-fw/1</code>).</p></footer>\n</main>\n</body>\n</html>\n");
}

const Section = enum { failed, rendering, not_run, project_skip };

fn section(w: W, r: Run, title: []const u8, which: Section) !void {
    var n: usize = 0;
    for (r.tests) |t| {
        const in = switch (which) {
            .failed => t.status == .FAIL or t.status.errored(),
            .rendering => t.not_run == .rendering,
            .not_run => t.not_run != null and t.not_run.? != .rendering and t.not_run.? != .project_skip,
            .project_skip => t.not_run == .project_skip,
        };
        if (!in) continue;
        if (n == 0) {
            try w.writeAll("<h2>");
            try html.text(w, title);
            try w.writeAll("</h2>\n<table class=\"listing\">\n<thead><tr><th>Test</th><th>Page</th><th>");
            try w.writeAll(if (which == .failed) "First failing assertion" else "Why");
            try w.writeAll("</th></tr></thead>\n<tbody>\n");
        }
        n += 1;
        try w.writeAll("<tr><th>");
        try html.text(w, t.id);
        if (which == .failed and t.status != .FAIL) try w.print(" <span class=\"fail\">({s})</span>", .{statusText(t.status)});
        try w.writeAll("</th><td><code>");
        try html.text(w, t.page);
        try w.writeAll("</code></td><td class=\"msg\"><pre>");
        const text = switch (which) {
            .failed => t.message orelse "",
            .project_skip => "the project skips it (QUnit.skip / Mocha pending)",
            else => t.reason orelse (if (t.not_run) |k| k.label() else ""),
        };
        try html.text(w, text[0..@min(text.len, 600)]);
        try w.writeAll("</pre></td></tr>\n");
    }
    if (n > 0) try w.writeAll("</tbody>\n</table>\n");
}

const testing = std.testing;

fn sampleSuite() manifest.Suite {
    return .{
        .id = "htmx-mocha",
        .framework = "htmx",
        .title = "htmx",
        .version = "4.0.1",
        .kind = .project,
        .repository = "https://github.com/bigskysoftware/htmx",
        .tag = "v4.0.1",
        .commit = "8d112c71624f2e48e741d740b4531d5010f057ae",
        .licence = "0BSD",
        .runner = "Mocha 11.7.5",
        .reader = .mocha,
        .source = .{ .url = "https://x", .sha256 = "b" },
        .pages = &.{.{ .id = "test", .path = "test/test.html" }},
        .excluded = "htmx-4.0.1.txt",
    };
}

test "the matrix: a row per suite with its counts and kind, the pending rows, the statement; text escaped" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const sha: [64]u8 = @splat('a');
    const base: journal.TestRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "htmx", .version = "4.0.1", .suite = "htmx-mocha", .suite_kind = .project, .source_sha256 = &sha, .page = "test", .module = "m", .name = "n", .id = "m <n>", .status = .PASS };
    var failed = base;
    failed.status = .FAIL;
    failed.id = "m fails";
    failed.message = "AssertionError: expected <b>";
    var excluded = base;
    excluded.status = .NOTRUN;
    excluded.not_run = .rendering;
    excluded.id = "m scrolls";
    excluded.reason = "asserts window.scrollY";
    const page: journal.PageRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "htmx", .version = "4.0.1", .suite = "htmx-mocha", .suite_kind = .project, .source_sha256 = &sha, .page = "test", .url = "u", .status = .OK, .wall_ms = 1000, .ran = 2, .records = 3, .exit = "exited with code 0" };
    const j: journal.Journal = .{ .tests = &.{ base, failed, excluded }, .pages = &.{page} };
    const m: manifest.Manifest = .{ .suites = &.{sampleSuite()} };
    const suites = try collect(a, m, &.{j}, &.{});
    try testing.expectEqual(@as(usize, 1), suites[0].runs.len);
    try testing.expectEqual(@as(u32, 1), suites[0].runs[0].counts.pass);

    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(&out.writer, suites, .{});
    const page_html = out.written();
    try testing.expect(std.mem.indexOf(u8, page_html, "Crane draws nothing") != null);
    try testing.expect(std.mem.indexOf(u8, page_html, "the project&#39;s own browser suite") != null);
    try testing.expect(std.mem.indexOf(u8, page_html, "<td class=\"n\">2</td><td class=\"n\">1</td><td class=\"n fail\">1</td>") != null);
    try testing.expect(std.mem.indexOf(u8, page_html, "50.0%") != null);
    for (pending) |p| try testing.expect(std.mem.indexOf(u8, page_html, p.title) != null);
    try testing.expect(std.mem.indexOf(u8, page_html, "<script") == null);

    var fw_out: Io.Writer.Allocating = .init(a);
    try writeSuites(&fw_out.writer, "htmx", suites, .{});
    const fw_html = fw_out.written();
    try testing.expect(std.mem.indexOf(u8, fw_html, "AssertionError: expected &lt;b&gt;") != null);
    try testing.expect(std.mem.indexOf(u8, fw_html, "asserts window.scrollY") != null);
    try testing.expect(std.mem.indexOf(u8, fw_html, "Crane draws nothing") != null);
    try testing.expect(std.mem.indexOf(u8, fw_html, "<b>") == null);
}

test "rate: one decimal, rounded; nothing run is a dash" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try rate(&out.writer, 1778, 1790);
    try rate(&out.writer, 0, 0);
    try testing.expectEqualStrings("99.3%&mdash;", out.written());
}
