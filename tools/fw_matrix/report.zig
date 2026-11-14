//! `fw_matrix report`: the JS framework compatibility matrix as finished
//! HTML, from journals only (tmp/plans/framework-matrix-plan.md, section 4):
//!
//!   <out>/index.html                 the matrix, in two sections: the
//!                                    frameworks' own test suites, then
//!                                    TodoMVC (the user, 2026-11-14: "TODOMVC
//!                                    is supposed to be called out
//!                                    separately in that report")
//!   <out>/<framework>/index.html     its own suites: every page, every
//!                                    failing test with its message, every
//!                                    excluded or not-run test with its
//!                                    reason; its own suites that do not run,
//!                                    with why
//!   <out>/todomvc/<app>/index.html   one TodoMVC app, the same way
//!
//! The site's rules (tools/wpt_site/DESIGN.md, PRODUCT.md): the content is in
//! the HTML (no script), graphs count tests, red is a failure, grey is
//! excluded or not run; it uses the WPT site's stylesheet and its HTML
//! helpers (tools/wpt_site/html.zig, by import). Every page says that
//! rendering tests are not run. A TodoMVC app never stands in for its
//! framework's own suite: it is only in the second section.

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
    /// The browser of a comparison run; null for Crane.
    browser: ?[]const u8 = null,
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
    /// The latest comparison run in a browser (`fw_matrix run --browser`).
    chrome: ?Run = null,
};

/// What the TodoMVC port does not run of a test (it excludes no test):
/// tools/fw_matrix/excluded/todomvc-port.txt says the same.
pub const todomvc_port_note =
    "Crane's port runs every test of TodoMVC's app spec (cypress/e2e/spec.cy.js, 29 tests) on the app's unmodified build, driving it through DOM events as Cypress drives it. Of Cypress's own checks it does not run the parts that need layout: visibility is decided by computed style (no box, visibility, opacity) and not by size, clipping or transforms, and an action does not scroll the element into view or check that nothing covers it. Cypress's hooks that run before the app's own scripts have no in-page equivalent: an app counts as started when its page has loaded and its heading is visible, and the spec's spy on localStorage.setItem is installed then. Tests the spec itself skips for an app (its localStorage test for apps that keep no data there, the app's entries in tests/knownIssues.js) are reported as skipped by the app spec.";

pub const statement =
    "Crane draws nothing: tests whose result depends on layout geometry or pixels are not run, and each is listed with its reason. Computed style, events, timers and animations are run. Tests a project runs only through its Node test runner are not run either, and are listed with theirs.";

/// Where Node runs (the user, 2026-11-11 17:43 ET: "we can run node for the
/// purposes of these tests").
pub const node_note =
    "Node runs only a project's own build step, test server and test runner, never inside Crane. jQuery's pages are served by its own test server (jquery-test-runner) with its own dependencies, as its CI serves them; Angular's are built by its own Bazel and served by its own web-test-runner debug targets, one per page; htmx's test page and the TodoMVC apps are static files, served as they are.";

/// The first section's introduction.
pub const own_suites_intro =
    "Each framework's own browser tests, run in Crane the way the project runs them in a browser: its own build, its own test server and its own test runner. A framework's own tests that Crane cannot run yet are listed with why. Suites whose runner drives the browser through a protocol Crane does not speak yet (the Chrome DevTools Protocol, WebDriver BiDi) wait until after Crane 0.1; Crane does not run them through a harness of its own instead.";

/// The second section's introduction.
pub const todomvc_intro =
    "The TodoMVC apps todomvc.com lists, each the app's unmodified build from tastejs/todomvc, checked by Crane's port of TodoMVC's app spec. These rows measure an app written with a framework, not the framework's own tests.";

/// The runs in `journals` grouped by suite, each suite's runs ordered by
/// generation (lane runs, with none, after) then label.
pub fn collect(arena: Allocator, m: manifest.Manifest, journals: []const journal.Journal, file_entries: []const []const exclusions.Entry) ![]SuiteRuns {
    var out: std.ArrayList(SuiteRuns) = .empty;
    for (m.suites, 0..) |s, si| {
        var runs: std.ArrayList(Run) = .empty;
        var chrome: ?Run = null;
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
                for (j.pages) |p| if (std.mem.eql(u8, p.suite, s.id) and std.mem.eql(u8, p.label, label)) {
                    try pages.append(arena, p);
                    // Tests the framework counted without naming them.
                    counts.pass += p.unnamed_passed orelse 0;
                    counts.project_skip += p.unnamed_pending orelse 0;
                };
                const first = pages.items[0];
                const run: Run = .{ .label = label, .browser = first.browser, .generation = first.generation, .crane_commit = first.crane_commit, .console_sha256 = first.console_sha256, .tests = tests.items, .pages = pages.items, .counts = counts };
                if (run.browser != null) {
                    // The latest by label (labels name their time).
                    if (chrome == null or std.mem.order(u8, chrome.?.label, label) == .lt) chrome = run;
                } else try runs.append(arena, run);
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
        try out.append(arena, .{ .suite = s, .runs = runs.items, .file_entries = if (si < file_entries.len) file_entries[si] else &.{}, .chrome = chrome });
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
    \\.fw .why { display: block; margin-top: 0.25rem; font: 400 0.82rem/1.4 var(--sans); color: var(--ink-2); max-width: 46rem; }
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
/// A TodoMVC app: "React 19.2.5 &mdash; examples/react/dist, checked by
/// Crane's port of the TodoMVC app spec (QUnit 2.24.2)"; the version is left
/// out where the app's files state none.
fn suiteLabel(w: W, s: manifest.Suite) !void {
    try html.text(w, s.title);
    if (s.app) |app| {
        if (app.version) |v| {
            try w.writeByte(' ');
            try html.text(w, v);
        }
        try w.writeAll(" &mdash; <code>");
        try html.text(w, s.tag);
        try w.writeAll("</code>, checked by Crane&#39;s port of the TodoMVC app spec (");
        try html.text(w, s.runner);
        try w.writeAll(")");
        return;
    }
    try w.writeByte(' ');
    try html.text(w, s.version);
    try w.writeAll(" &mdash; ");
    try html.text(w, journal.SuiteKind.label(s.kind));
    try w.writeAll(" (");
    try html.text(w, s.runner);
    try w.print(", {d} page{s})", .{ s.pages.len, if (s.pages.len == 1) "" else "s" });
}

/// What TodoMVC's own runner says of the app, where it skips it; a suite's
/// own note.
fn appNote(w: W, s: manifest.Suite) !void {
    if (s.note) |n| {
        try w.writeAll("<span class=\"why\">");
        try html.text(w, n);
        try w.writeAll("</span>");
    }
    const app = s.app orelse return;
    const why = app.skipped_by_todomvc orelse return;
    try w.writeAll("<span class=\"why\">TodoMVC&#39;s own runner skips this app (tests/excluded.js): ");
    try html.text(w, why);
    try w.writeAll(". It is run here all the same.</span>");
}

const table_head = "<table class=\"listing\">\n<thead><tr><th>{s}</th><th class=\"n\">Run</th><th class=\"n\">Passed</th><th class=\"n\">Failed</th><th class=\"n\">Errored</th><th class=\"n\">Excluded: rendering</th><th class=\"n\">Not run</th><th class=\"n\">Pass rate</th><th class=\"n\">Chrome</th><th>History</th></tr></thead>\n<tbody>\n";

/// Where a suite's page is, below the matrix: a framework's own suites at
/// "<framework>/", a TodoMVC app at "todomvc/<app>/".
pub fn pageDir(s: manifest.Suite) [2][]const u8 {
    return switch (s.kind) {
        .project => .{ "", s.framework },
        .todomvc_port => .{ "todomvc/", s.framework },
    };
}

/// One suite's row: its counts in the latest run, its history.
fn suiteRow(w: W, s: SuiteRuns) !void {
    const dir = pageDir(s.suite);
    try w.writeAll("<tr><th><a href=\"");
    try html.text(w, dir[0]);
    try html.text(w, dir[1]);
    try w.writeAll("/\">");
    try html.text(w, s.suite.title);
    try w.writeAll("</a><span class=\"kind\">");
    try suiteLabel(w, s.suite);
    try w.writeAll("</span>");
    try appNote(w, s.suite);
    if (latest(s)) |r| try meter(w, r.counts);
    try w.writeAll("</th>");
    if (latest(s)) |r| {
        const c = r.counts;
        try w.print("<td class=\"n\">{d}</td><td class=\"n\">{d}</td><td class=\"n{s}\">{d}</td><td class=\"n{s}\">{d}</td><td class=\"n grey\">{d}</td><td class=\"n grey\">{d}</td><td class=\"n\">", .{
            c.ran(), c.pass, if (c.fail > 0) " fail" else "", c.fail, if (c.errored() > 0) " fail" else "", c.errored(), c.rendering, c.not_run + c.project_skip + @as(u32, @intCast(s.file_entries.len)),
        });
        try rate(w, c.pass, c.ran());
        try w.writeAll("</td>");
        try chromeCell(w, s);
        try w.writeAll("<td>");
        try sparkline(w, s.runs);
        try w.writeAll("</td></tr>\n");
    } else {
        try w.writeAll("<td class=\"n\" colspan=\"7\">no run yet</td>");
        try chromeCell(w, s);
        try w.writeAll("<td></td></tr>\n");
    }
}

/// Chrome's passed of run for the suite: its latest comparison run, else
/// the project runner's numbers the manifest records; a dash with neither.
fn chromeCell(w: W, s: SuiteRuns) !void {
    if (s.chrome) |r| {
        try w.writeAll("<td class=\"n\" title=\"");
        try html.text(w, r.browser orelse "");
        try w.writeAll(", run ");
        try html.text(w, r.label);
        try w.writeAll(": passed of run\">");
        try html.num(w, r.counts.pass);
        try w.writeAll(" of ");
        try html.num(w, r.counts.ran());
        return w.writeAll("</td>");
    }
    if (s.suite.chrome_reference) |c| {
        try w.writeAll("<td class=\"n\" title=\"");
        try html.text(w, c.browser);
        try w.writeAll(", ");
        try html.text(w, c.runner);
        try w.writeAll(", ");
        try html.text(w, c.date);
        try w.writeAll(": passed of run\">");
        try html.num(w, c.passed);
        try w.writeAll(" of ");
        try html.num(w, c.ran);
        return w.writeAll("</td>");
    }
    try w.writeAll("<td class=\"n grey\">&mdash;</td>");
}

/// "e2e (Puppeteer on Chrome), Vue 3.5.45": what a not-run row names.
fn notRunLabel(w: W, fw: manifest.Framework, n: manifest.OwnSuiteNotRun) !void {
    try html.text(w, fw.title);
    try w.writeByte(' ');
    try html.text(w, n.version);
    try w.writeAll(" &mdash; its own ");
    try html.text(w, n.name);
    try w.writeAll(" (");
    try html.text(w, n.runner);
    try w.writeAll(")");
}

/// A framework's own suite that does not run: its row says why.
fn notRunRow(w: W, fw: manifest.Framework, n: manifest.OwnSuiteNotRun) !void {
    try w.writeAll("<tr><th><a href=\"");
    try html.text(w, fw.id);
    try w.writeAll("/\">");
    try html.text(w, fw.title);
    try w.writeAll("</a><span class=\"kind\">");
    try notRunLabel(w, fw, n);
    try w.writeAll("</span><span class=\"why\">Not run: ");
    try html.text(w, n.why);
    try w.writeAll("</span></th><td class=\"n grey\">&mdash;</td><td class=\"n grey\">&mdash;</td><td class=\"n grey\">&mdash;</td><td class=\"n grey\">&mdash;</td><td class=\"n grey\">&mdash;</td><td class=\"n grey\">");
    if (n.tests) |t| try html.num(w, t) else try w.writeAll("all");
    try w.writeAll("</td><td class=\"n grey\">&mdash;</td><td class=\"n grey\">&mdash;</td><td></td></tr>\n");
}

pub fn writeIndex(w: W, frameworks: []const manifest.Framework, todomvc: ?manifest.TodoMvc, suites: []const SuiteRuns, o: Options) !void {
    try head(w, "Crane: JS framework compatibility matrix", "JavaScript frameworks' own browser tests, and the TodoMVC apps, run in Crane, with rendering tests excluded and named.", o, 0);
    try w.writeAll("<header class=\"head\">\n<h1>Crane <span class=\"h1-rest\">JS framework compatibility matrix</span></h1>\n<p class=\"subtitle\">Two sections: the frameworks' own test suites, and the TodoMVC apps. Each page is opened in Crane's console as a user opens it and read from the test framework's own report. ");
    try html.text(w, node_note);
    try w.writeAll("</p>\n</header>\n");
    try statementNote(w);

    try w.writeAll("<h2 id=\"own\">The frameworks' own test suites</h2>\n<p>");
    try html.text(w, own_suites_intro);
    try w.writeAll("</p>\n");
    try w.print(table_head, .{"Framework"});
    if (frameworks.len == 0) {
        for (suites) |s| if (s.suite.kind == .project) try suiteRow(w, s);
    } else for (frameworks) |fw| {
        for (suites) |s| if (s.suite.kind == .project and std.mem.eql(u8, s.suite.framework, fw.id)) try suiteRow(w, s);
        for (fw.not_run) |n| try notRunRow(w, fw, n);
    }
    try w.writeAll("</tbody>\n</table>\n");

    var any_app = todomvc != null;
    for (suites) |s| any_app = any_app or s.suite.kind == .todomvc_port;
    if (any_app) {
        try w.writeAll("<h2 id=\"todomvc\">TodoMVC (Crane's port of the TodoMVC app spec)</h2>\n<p>");
        try html.text(w, todomvc_intro);
        if (todomvc) |t| {
            var served: usize = 0;
            for (t.apps) |app| served += @intFromBool(app.not_served == null);
            try w.print(" todomvc.com lists {d} apps; {d} are run, ", .{ t.apps.len, served });
            try w.writeAll("from tastejs/todomvc at <code>");
            try html.text(w, t.commit[0..@min(12, t.commit.len)]);
            try w.writeAll("</code>.");
        }
        try w.writeAll("</p>\n");
        try w.print(table_head, .{"App"});
        for (suites) |s| if (s.suite.kind == .todomvc_port) try suiteRow(w, s);
        if (todomvc) |t| for (t.apps) |app| if (app.not_served) |why| {
            try w.writeAll("<tr><th>");
            try html.text(w, app.title);
            try w.writeAll("<span class=\"kind\"><code>examples/");
            try html.text(w, app.folder);
            try w.writeAll("</code></span><span class=\"why\">Cannot be served: ");
            try html.text(w, why);
            try w.writeAll("</span></th><td class=\"n grey\" colspan=\"9\">not run</td></tr>\n");
        };
        try w.writeAll("</tbody>\n</table>\n");
    }
    try w.writeAll("<p class=\"grey\">Pass rate is passed over run. Errored: due to run and never reported (the page's time ran out, or the console ended). Not run: every kind is counted under What we do not run, below.</p>\n");
    try writeNotRun(w, suites);
    try w.writeAll("<footer class=\"foot\"><p>Written as HTML by <code>tools/fw_matrix</code> from its journals (<code>crane-fw/1</code>).</p></footer>\n</main>\n</body>\n</html>\n");
}

/// One kind of test not run, counted over each suite's latest run.
const NotRunRow = struct {
    title: []const u8,
    files: bool = false,
    count: *const fn (s: SuiteRuns, r: Run) u32,
};

fn countKind(r: Run, kind: journal.NotRun) u32 {
    var n: u32 = 0;
    for (r.tests) |t| {
        if (t.not_run == kind) n += 1;
    }
    return n;
}

const not_run_rows = [_]NotRunRow{
    .{ .title = "Excluded: rendering", .count = struct {
        fn f(_: SuiteRuns, r: Run) u32 {
            return countKind(r, .rendering);
        }
    }.f },
    .{ .title = "Needs the project's test server", .count = struct {
        fn f(_: SuiteRuns, r: Run) u32 {
            return countKind(r, .needs_server);
        }
    }.f },
    .{ .title = "Needs the project's Node build", .count = struct {
        fn f(_: SuiteRuns, r: Run) u32 {
            return countKind(r, .needs_node_build);
        }
    }.f },
    .{ .title = "Files only the project's Node runner loads", .files = true, .count = struct {
        fn f(s: SuiteRuns, _: Run) u32 {
            return @intCast(s.file_entries.len);
        }
    }.f },
    .{ .title = "Skipped by the project", .count = struct {
        fn f(s: SuiteRuns, r: Run) u32 {
            return if (s.suite.kind == .project) countKind(r, .project_skip) else 0;
        }
    }.f },
    .{ .title = "Skipped by TodoMVC's app spec for the app", .count = struct {
        fn f(s: SuiteRuns, r: Run) u32 {
            return if (s.suite.kind == .todomvc_port) countKind(r, .project_skip) else 0;
        }
    }.f },
};

/// "What we do not run": every kind with its count over the frameworks'
/// latest runs, and where; a kind with none is left out.
fn writeNotRun(w: W, suites: []const SuiteRuns) !void {
    try w.writeAll("<h2 id=\"not-run\">What we do not run</h2>\n<p>");
    try html.text(w, statement);
    try w.writeAll(" Each test is listed with its reason on its framework's page.</p>\n<table class=\"listing\">\n<thead><tr><th>Kind</th><th class=\"n\">Count</th><th>Where</th></tr></thead>\n<tbody>\n");
    for (not_run_rows) |row| {
        var total: u32 = 0;
        for (suites) |s| if (latest(s)) |r| {
            total += row.count(s, r);
        };
        if (total == 0) continue;
        try w.writeAll("<tr><th>");
        try html.text(w, row.title);
        try w.print("</th><td class=\"n grey\">{d}", .{total});
        if (row.files) try w.print(" file{s}", .{if (total == 1) "" else "s"});
        try w.writeAll("</td><td>");
        var first = true;
        for (suites) |s| if (latest(s)) |r| {
            const n = row.count(s, r);
            if (n == 0) continue;
            if (!first) try w.writeAll(", ");
            first = false;
            try html.text(w, s.suite.title);
            try w.print(" {d}", .{n});
        };
        try w.writeAll("</td></tr>\n");
    }
    try w.writeAll("</tbody>\n</table>\n");
    var any_port = false;
    for (suites) |s| any_port = any_port or s.suite.kind == .todomvc_port;
    if (any_port) {
        try w.writeAll("<p>");
        try html.text(w, todomvc_port_note);
        try w.writeAll("</p>\n");
    }
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

const page_foot = "<footer class=\"foot\"><p>Written as HTML by <code>tools/fw_matrix</code> from its journals (<code>crane-fw/1</code>).</p></footer>\n</main>\n</body>\n</html>\n";

/// A framework's page (<out>/<framework>/): its own suites that run, then
/// those that do not, with why; its TodoMVC app is linked, never shown here.
pub fn writeFramework(w: W, fw: manifest.Framework, suites: []const SuiteRuns, o: Options) !void {
    var title_buf: [128]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Crane: {s}'s own tests in the JS framework matrix", .{fw.title}) catch fw.title;
    try head(w, title, "A framework's own browser test suites run in Crane: every failure with its message, every excluded test with its reason, every suite not run with why.", o, 1);
    try w.writeAll("<header class=\"head\">\n<h1>");
    try html.text(w, fw.title);
    try w.writeAll(" <span class=\"h1-rest\">in Crane</span></h1>\n<p class=\"subtitle\">The project's own test suites. <a href=\"../\">The matrix</a>.");
    for (suites) |s| if (s.suite.kind == .todomvc_port and std.mem.eql(u8, s.suite.framework, fw.id)) {
        try w.writeAll(" Its TodoMVC app, a separate measure: <a href=\"../todomvc/");
        try html.text(w, s.suite.framework);
        try w.writeAll("/\">");
        try html.text(w, s.suite.title);
        try w.writeAll(" TodoMVC</a>.");
    };
    try w.writeAll("</p>\n</header>\n");
    try statementNote(w);
    for (suites) |s| if (s.suite.kind == .project and std.mem.eql(u8, s.suite.framework, fw.id)) try suiteBody(w, s);
    if (fw.not_run.len > 0) {
        try w.writeAll("<h2 id=\"not-run-suites\">Its own tests Crane does not run</h2>\n<table class=\"listing\">\n<thead><tr><th>Tests</th><th class=\"n\">Count</th><th>Why</th></tr></thead>\n<tbody>\n");
        for (fw.not_run) |n| {
            try w.writeAll("<tr><th>");
            try notRunLabel(w, fw, n);
            try w.writeAll(", <a href=\"");
            try html.text(w, n.repository);
            try w.writeAll("/tree/");
            try html.text(w, n.tag);
            try w.writeAll("\">");
            try html.text(w, n.tag);
            try w.writeAll("</a></th><td class=\"n grey\">");
            if (n.tests) |t| try html.num(w, t) else try w.writeAll("not counted");
            try w.writeAll("</td><td>");
            try html.text(w, n.why);
            try w.writeAll("</td></tr>\n");
        }
        try w.writeAll("</tbody>\n</table>\n");
    }
    try w.writeAll(page_foot);
}

/// A TodoMVC app's page (<out>/todomvc/<app>/).
pub fn writeApp(w: W, s: SuiteRuns, o: Options) !void {
    var title_buf: [128]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Crane: the {s} TodoMVC app in the JS framework matrix", .{s.suite.title}) catch s.suite.title;
    try head(w, title, "A TodoMVC app checked in Crane by Crane's port of the TodoMVC app spec: every failure with its message.", o, 2);
    try w.writeAll("<header class=\"head\">\n<h1>");
    try html.text(w, s.suite.title);
    try w.writeAll(" <span class=\"h1-rest\">TodoMVC in Crane</span></h1>\n<p class=\"subtitle\">");
    try suiteLabel(w, s.suite);
    try w.writeAll(". <a href=\"../../#todomvc\">The matrix</a>.</p>\n</header>\n");
    try statementNote(w);
    if (s.suite.app) |app| {
        try w.writeAll("<p>The app&#39;s build: <code>examples/");
        try html.text(w, app.folder);
        try w.writeAll("</code> as committed in ");
        try html.text(w, s.suite.repository);
        try w.writeAll(" at <code>");
        try html.text(w, s.suite.commit[0..@min(12, s.suite.commit.len)]);
        try w.writeAll("</code>, unmodified; <code>examples/");
        try html.text(w, app.id);
        try w.writeAll("/</code> is pinned by its sha256 <code>");
        if (app.sha256) |h| try html.text(w, h[0..@min(16, h.len)]);
        try w.writeAll("&hellip;</code>, checked at every fetch.");
        if (app.skipped_by_todomvc) |why| {
            try w.writeAll(" TodoMVC&#39;s own runner skips this app (tests/excluded.js): ");
            try html.text(w, why);
            try w.writeAll(". It is run here all the same.");
        }
        try w.writeAll("</p>\n");
    }
    try w.writeAll("<p>");
    try html.text(w, todomvc_port_note);
    try w.writeAll(" The port: <code>tests/frameworks/todomvc/</code> in Crane; the spec: <a href=\"");
    try html.text(w, s.suite.repository);
    try w.writeAll("/blob/");
    try html.text(w, s.suite.commit);
    try w.writeAll("/cypress/e2e/spec.cy.js\"><code>cypress/e2e/spec.cy.js</code></a>.</p>\n");
    try suiteBody(w, s);
    try w.writeAll(page_foot);
}

/// One suite's run on its page: the run, its pages, its failures and what
/// it did not run.
fn suiteBody(w: W, s: SuiteRuns) !void {
    {
        const r = latest(s) orelse {
            try w.writeAll("<h2>");
            try suiteLabel(w, s.suite);
            try w.writeAll("</h2>\n");
            if (s.suite.note) |n| {
                try w.writeAll("<p>");
                try html.text(w, n);
                try w.writeAll("</p>\n");
            }
            try w.writeAll("<p>No run yet.</p>\n");
            return;
        };
        // A framework's page may hold several suites: each is headed by its
        // label; an app's page holds one run.
        if (s.suite.kind == .project) {
            try w.writeAll("<h2>");
            try suiteLabel(w, s.suite);
            try w.writeAll("</h2>\n");
            if (s.suite.note) |n| {
                try w.writeAll("<p>");
                try html.text(w, n);
                try w.writeAll("</p>\n");
            }
            try w.writeAll("<p>");
        } else try w.writeAll("<h2>The run</h2>\n<p>");
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
        try w.writeAll("</code>.");
        if (r.pages.len > 0) if (r.pages[0].server) |srv| {
            try w.writeAll(" Served by the project's own test server, ");
            try html.text(w, srv.name);
            if (srv.node) |n| {
                try w.writeAll(", under Node ");
                try html.text(w, n);
            }
            if (srv.node_modules_sha256) |h| {
                try w.writeAll(" (its node_modules sha256 <code>");
                try html.text(w, h[0..@min(16, h.len)]);
                try w.writeAll("&hellip;</code>)");
            }
            if (srv.bazel) |bz| {
                try w.writeAll(", run by the project&#39;s own Bazel ");
                try html.text(w, bz);
                if (srv.bazel_lock_sha256) |h| {
                    try w.writeAll(" (its MODULE.bazel.lock sha256 <code>");
                    try html.text(w, h[0..@min(16, h.len)]);
                    try w.writeAll("&hellip;</code>)");
                }
                try w.writeAll(", one target per page");
            }
            try w.writeAll(".");
        };
        try w.writeAll("</p>\n");
        try meter(w, r.counts);
        if (s.chrome) |c| {
            try w.writeAll("<p>For comparison, ");
            try html.text(w, c.browser orelse "");
            try w.writeAll(" ran the same page");
            if (c.pages.len != 1) try w.writeAll("s");
            try w.writeAll(" (run <code>");
            try html.text(w, c.label);
            try w.writeAll("</code>): ");
            try html.num(w, c.counts.pass);
            try w.writeAll(" passed of ");
            try html.num(w, c.counts.ran());
            try w.writeAll(" run, ");
            try html.num(w, c.counts.fail + c.counts.errored());
            try w.writeAll(" failed or errored.</p>\n");
        } else if (s.suite.chrome_reference) |c| {
            try w.writeAll("<p>For comparison, ");
            try html.text(w, c.browser);
            try w.writeAll(" by the project&#39;s own runner (");
            try html.text(w, c.runner);
            try w.writeAll(", ");
            try html.text(w, c.date);
            try w.writeAll("): ");
            try html.num(w, c.passed);
            try w.writeAll(" passed of ");
            try html.num(w, c.ran);
            try w.writeAll(" run, ");
            try html.num(w, c.failed);
            try w.writeAll(" failed.</p>\n");
        }

        try w.writeAll("<table class=\"listing\">\n<thead><tr><th>Page</th><th>Outcome</th><th class=\"n\">Run</th><th class=\"n\">Failed</th><th class=\"n\">Excluded</th><th class=\"n\">Not run</th><th class=\"n\">Seconds</th></tr></thead>\n<tbody>\n");
        for (r.pages) |p| {
            var c: journal.Counts = .{};
            for (r.tests) |t| if (std.mem.eql(u8, t.page, p.page)) c.add(t);
            c.pass += p.unnamed_passed orelse 0;
            c.project_skip += p.unnamed_pending orelse 0;
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

        try section(w, s.suite.kind, r, s.chrome, "Failed and errored", .failed);
        try section(w, s.suite.kind, r, null, "Excluded: rendering", .rendering);
        try section(w, s.suite.kind, r, null, "Not run", .not_run);
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
        try section(w, s.suite.kind, r, null, if (s.suite.kind == .todomvc_port) "Skipped by TodoMVC's app spec" else "Skipped by the project", .project_skip);

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
}

const Section = enum { failed, rendering, not_run, project_skip };

/// A failure Chrome's comparison run shares is marked: it is not a Crane
/// finding (lesson testing-a-framework-failure-chrome-shares-is-not-a-
/// crane-finding.md).
fn section(w: W, kind: journal.SuiteKind, r: Run, chrome: ?Run, title: []const u8, which: Section) !void {
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
        if (chrome) |c| for (c.tests) |ct| {
            if (std.mem.eql(u8, ct.id, t.id) and (ct.status == .FAIL or ct.status.errored())) {
                try w.writeAll(" <span class=\"grey\">(Chrome fails it too)</span>");
                break;
            }
        };
        try w.writeAll("</th><td><code>");
        try html.text(w, t.page);
        try w.writeAll("</code></td><td class=\"msg\"><pre>");
        const text = switch (which) {
            .failed => t.message orelse "",
            .project_skip => switch (kind) {
                .project => "the project skips it (QUnit.skip / Mocha pending)",
                .todomvc_port => "TodoMVC's app spec skips it for this app (spec.cy.js: its localStorage test for apps that keep nothing there; tests/knownIssues.js: the app's known issues)",
            },
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

fn sampleTodoMvcSuite() manifest.Suite {
    return .{
        .id = "angular-todomvc",
        .framework = "angular",
        .title = "Angular",
        .version = "21.2.11",
        .kind = .todomvc_port,
        .repository = "https://github.com/tastejs/todomvc",
        .tag = "examples/angular/dist/browser",
        .commit = "ff43b02e59dfa604386bb382034b2cd07c2bcd8a",
        .licence = "MIT",
        .runner = "QUnit 2.24.2",
        .reader = .qunit,
        .source = .{ .url = "https://x", .sha256 = "b" },
        .pages = &.{.{ .id = "todomvc", .path = "crane/todomvc/index.html?framework=angular" }},
        .excluded = "todomvc-port.txt",
    };
}

test "the matrix: a row per suite with its counts and kind, the statement; text escaped" {
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
    try writeIndex(&out.writer, &.{}, null, suites, .{});
    const page_html = out.written();
    try testing.expect(std.mem.indexOf(u8, page_html, "Crane draws nothing") != null);
    try testing.expect(std.mem.indexOf(u8, page_html, "the project&#39;s own browser suite") != null);
    try testing.expect(std.mem.indexOf(u8, page_html, "<td class=\"n\">2</td><td class=\"n\">1</td><td class=\"n fail\">1</td>") != null);
    try testing.expect(std.mem.indexOf(u8, page_html, "50.0%") != null);
    // No placeholder rows: a framework is a row only through a suite.
    try testing.expect(std.mem.indexOf(u8, page_html, "Not run yet") == null);
    try testing.expect(std.mem.indexOf(u8, page_html, "<script") == null);

    var fw_out: Io.Writer.Allocating = .init(a);
    try writeFramework(&fw_out.writer, .{ .id = "htmx", .title = "htmx" }, suites, .{});
    const fw_html = fw_out.written();
    try testing.expect(std.mem.indexOf(u8, fw_html, "AssertionError: expected &lt;b&gt;") != null);
    try testing.expect(std.mem.indexOf(u8, fw_html, "asserts window.scrollY") != null);
    try testing.expect(std.mem.indexOf(u8, fw_html, "Crane draws nothing") != null);
    try testing.expect(std.mem.indexOf(u8, fw_html, "<b>") == null);
}

test "two sections: the frameworks' own suites (with those not run, and why), then TodoMVC; what is not run is counted by kind" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const sha: [64]u8 = @splat('a');
    const jq: journal.TestRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "htmx", .version = "4.0.1", .suite = "htmx-mocha", .suite_kind = .project, .source_sha256 = &sha, .page = "test", .module = "m", .name = "n", .id = "m n", .status = .NOTRUN, .not_run = .rendering, .reason = "scrollY" };
    var jq2 = jq;
    jq2.id = "m n2";
    var jq_server = jq;
    jq_server.id = "m server";
    jq_server.not_run = .needs_server;
    var jq_skip = jq;
    jq_skip.id = "m skip";
    jq_skip.not_run = .project_skip;
    const ng: journal.TestRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "angular", .version = "21.2.11", .suite = "angular-todomvc", .suite_kind = .todomvc_port, .source_sha256 = &sha, .page = "todomvc", .module = "Routing", .name = "should respect the back button", .id = "Routing: should respect the back button", .status = .NOTRUN, .not_run = .project_skip };
    var ng_pass = ng;
    ng_pass.id = "No Todos: starts with nothing";
    ng_pass.status = .PASS;
    ng_pass.not_run = null;
    const p1: journal.PageRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "htmx", .version = "4.0.1", .suite = "htmx-mocha", .suite_kind = .project, .source_sha256 = &sha, .page = "test", .url = "u", .status = .OK, .wall_ms = 1000, .ran = 0, .records = 4, .exit = "exited with code 0" };
    var p2 = p1;
    p2.framework = "angular";
    p2.version = "21.2.11";
    p2.suite = "angular-todomvc";
    p2.suite_kind = .todomvc_port;
    p2.page = "todomvc";
    const j: journal.Journal = .{ .tests = &.{ jq, jq2, jq_server, jq_skip, ng, ng_pass }, .pages = &.{ p1, p2 } };
    const m: manifest.Manifest = .{ .suites = &.{ sampleSuite(), sampleTodoMvcSuite() } };
    const file_entries = [_][]const exclusions.Entry{ &.{.{ .id = "test/a.js", .file = true, .kind = .node_runner_only, .why = "w", .line = 1 }}, &.{} };
    const suites = try collect(a, m, &.{j}, &file_entries);

    var out: Io.Writer.Allocating = .init(a);
    const react: manifest.Framework = .{ .id = "react", .title = "React", .not_run = &.{.{ .name = "Playwright end-to-end tests", .version = "19.3.1", .repository = "https://github.com/facebook/react", .tag = "v19.3.1", .runner = "Playwright on Chromium", .tests = 19, .why = "Playwright drives Chromium through the Chrome DevTools Protocol." }} };
    const frameworks = [_]manifest.Framework{ .{ .id = "htmx", .title = "htmx" }, react, .{ .id = "angular", .title = "Angular", .not_run = &.{.{ .name = "web tests", .version = "22.2.6", .repository = "https://github.com/angular/angular", .tag = "v22.2.6", .runner = "web-test-runner", .why = "w" }} } };
    try writeIndex(&out.writer, &frameworks, null, suites, .{});
    const html_out = out.written();
    // The user, 2026-11-14: TodoMVC is its own section; an app never stands
    // in for its framework's own suite.
    const own = std.mem.indexOf(u8, html_out, "<h2 id=\"own\">The frameworks' own test suites</h2>").?;
    const todo = std.mem.indexOf(u8, html_out, "<h2 id=\"todomvc\">TodoMVC (Crane's port of the TodoMVC app spec)</h2>").?;
    try testing.expect(own < todo);
    const htmx_row = std.mem.indexOf(u8, html_out, "<tr><th><a href=\"htmx/\">htmx</a>").?;
    try testing.expect(own < htmx_row and htmx_row < todo);
    // A framework whose own tests do not run is a row of the first section,
    // saying why, with how many tests.
    const react_row = std.mem.indexOf(u8, html_out, "<tr><th><a href=\"react/\">React</a><span class=\"kind\">React 19.3.1 &mdash; its own Playwright end-to-end tests (Playwright on Chromium)</span><span class=\"why\">Not run: Playwright drives Chromium through the Chrome DevTools Protocol.</span></th>").?;
    try testing.expect(react_row < todo);
    try testing.expect(std.mem.indexOf(u8, html_out[react_row..], "<td class=\"n grey\">19</td>") != null);
    // The app's row is in the second section only, and links its own page.
    const app_row = std.mem.indexOf(u8, html_out, "<tr><th><a href=\"todomvc/angular/\">Angular</a>").?;
    try testing.expect(app_row > todo);
    try testing.expect(std.mem.indexOf(u8, html_out, "the framework&#39;s TodoMVC app, checked by Crane&#39;s port of the TodoMVC app spec") != null);
    try testing.expect(std.mem.indexOf(u8, html_out, "not runnable without Node") == null);
    // What is not run: one row per kind, its count, and where.
    try testing.expect(std.mem.indexOf(u8, html_out, "<h2 id=\"not-run\">What we do not run</h2>") != null);
    try testing.expect(std.mem.indexOf(u8, html_out, "<tr><th>Excluded: rendering</th><td class=\"n grey\">2</td><td>htmx 2</td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, html_out, "<tr><th>Needs the project&#39;s test server</th><td class=\"n grey\">1</td><td>htmx 1</td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, html_out, "<tr><th>Files only the project&#39;s Node runner loads</th><td class=\"n grey\">1 file</td><td>htmx 1</td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, html_out, "<tr><th>Skipped by the project</th><td class=\"n grey\">1</td><td>htmx 1</td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, html_out, "<tr><th>Skipped by TodoMVC&#39;s app spec for the app</th><td class=\"n grey\">1</td><td>Angular 1</td></tr>") != null);
    // A kind with nothing in it is not listed.
    try testing.expect(std.mem.indexOf(u8, html_out, "Needs the project&#39;s Node build") == null);

    var fw_out: Io.Writer.Allocating = .init(a);
    try writeApp(&fw_out.writer, suites[1], .{});
    const app_html = fw_out.written();
    try testing.expect(std.mem.indexOf(u8, app_html, "TodoMVC&#39;s app spec skips it for this app") != null);
    try testing.expect(std.mem.indexOf(u8, app_html, "cypress/e2e/spec.cy.js") != null);
    // Two levels below the matrix, which is one below the site's root.
    try testing.expect(std.mem.indexOf(u8, app_html, "href=\"../../../site.css\"") != null);
    try testing.expect(std.mem.indexOf(u8, app_html, "<a href=\"../../#todomvc\">The matrix</a>") != null);

    // The framework's page: its own tests not run, with why; its TodoMVC
    // app only linked.
    var ng_out: Io.Writer.Allocating = .init(a);
    try writeFramework(&ng_out.writer, frameworks[2], suites, .{});
    const ng_html = ng_out.written();
    try testing.expect(std.mem.indexOf(u8, ng_html, "<h2 id=\"not-run-suites\">Its own tests Crane does not run</h2>") != null);
    try testing.expect(std.mem.indexOf(u8, ng_html, "<a href=\"https://github.com/angular/angular/tree/v22.2.6\">v22.2.6</a>") != null);
    try testing.expect(std.mem.indexOf(u8, ng_html, "<a href=\"../todomvc/angular/\">Angular TodoMVC</a>") != null);
    try testing.expect(std.mem.indexOf(u8, ng_html, "Routing: should respect the back button") == null);
}

test "where Node runs is said: on the matrix, and on the page of a suite its project's own server served" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const sha: [64]u8 = @splat('a');
    const nm: [64]u8 = @splat('c');
    var suite = sampleSuite();
    suite.id = "jquery-qunit";
    suite.framework = "jquery";
    suite.title = "jQuery";
    suite.version = "4.0.0";
    const t: journal.TestRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "jquery", .version = "4.0.0", .suite = "jquery-qunit", .suite_kind = .project, .source_sha256 = &sha, .page = "ajax", .module = "ajax", .name = "n", .id = "ajax: n", .status = .PASS };
    const p: journal.PageRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "jquery", .version = "4.0.0", .suite = "jquery-qunit", .suite_kind = .project, .source_sha256 = &sha, .page = "ajax", .url = "u", .status = .OK, .wall_ms = 1000, .ran = 1, .records = 1, .exit = "exited with code 0", .server = .{ .name = "jquery-test-runner 0.3.0", .node = "24.22.3", .node_modules_sha256 = &nm } };
    const suites = try collect(a, .{ .suites = &.{suite} }, &.{.{ .tests = &.{t}, .pages = &.{p} }}, &.{});

    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(&out.writer, &.{}, null, suites, .{});
    // The b3 page said "No Node runs at any step": no longer true.
    try testing.expect(std.mem.indexOf(u8, out.written(), "No Node runs") == null);
    try testing.expect(std.mem.indexOf(u8, out.written(), "Node runs only a project&#39;s own build step, test server and test runner, never inside Crane") != null);

    var fw_out: Io.Writer.Allocating = .init(a);
    try writeFramework(&fw_out.writer, .{ .id = "jquery", .title = "jQuery" }, suites, .{});
    try testing.expect(std.mem.indexOf(u8, fw_out.written(), "Served by the project's own test server, jquery-test-runner 0.3.0, under Node 24.22.3 (its node_modules sha256 <code>cccccccccccccccc&hellip;</code>).") != null);
}

test "TodoMVC rows: each app's build and pin, TodoMVC's own skip beside it, and the apps that cannot be served" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const sha: [64]u8 = @splat('a');
    const pin: [64]u8 = @splat('b');
    const gwt_app: manifest.App = .{ .id = "gwt", .title = "GWT", .folder = "gwt", .sha256 = &pin, .skipped_by_todomvc = "this implementation deviates from the specification" };
    const es5_app: manifest.App = .{ .id = "javascript-es5", .title = "JavaScript ES5", .folder = "javascript-es5/dist", .sha256 = &pin };
    const t: manifest.TodoMvc = .{
        .repository = "https://github.com/tastejs/todomvc",
        .commit = "ff43b02e59dfa604386bb382034b2cd07c2bcd8a",
        .licence = "MIT",
        .runner = "QUnit 2.24.2",
        .reader = .qunit,
        .source = .{ .url = "https://x", .sha256 = "b" },
        .page = "crane/todomvc/index.html",
        .excluded = "todomvc-port.txt",
        .apps = &.{ gwt_app, es5_app, .{ .id = "somajs", .title = "soma.js", .folder = "somajs", .not_served = "404 on todomvc.com itself" } },
    };
    const expanded = try manifest.expandTodoMvc(a, &.{}, t);
    try testing.expectEqual(@as(usize, 2), expanded.len);
    const rec: journal.TestRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "javascript-es5", .version = "ff43b02e59df", .suite = "javascript-es5-todomvc", .suite_kind = .todomvc_port, .source_sha256 = &sha, .page = "todomvc", .module = "New Todo", .name = "should allow me to add todo items", .id = "New Todo: should allow me to add todo items", .status = .PASS };
    const page: journal.PageRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "javascript-es5", .version = "ff43b02e59df", .suite = "javascript-es5-todomvc", .suite_kind = .todomvc_port, .source_sha256 = &sha, .page = "todomvc", .url = "u", .status = .OK, .wall_ms = 1000, .ran = 1, .records = 1, .exit = "exited with code 0" };
    const suites = try collect(a, .{ .suites = expanded }, &.{.{ .tests = &.{rec}, .pages = &.{page} }}, &.{});

    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(&out.writer, &.{}, t, suites, .{});
    const h = out.written();
    try testing.expect(std.mem.indexOf(u8, h, "todomvc.com lists 3 apps; 2 are run, from tastejs/todomvc at <code>ff43b02e59df</code>.") != null);
    // No version the app's files state: none shown (the commit pins it).
    try testing.expect(std.mem.indexOf(u8, h, "<a href=\"todomvc/javascript-es5/\">JavaScript ES5</a><span class=\"kind\">JavaScript ES5 &mdash; <code>examples/javascript-es5/dist</code>, checked by Crane&#39;s port of the TodoMVC app spec (QUnit 2.24.2)</span>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "TodoMVC&#39;s own runner skips this app (tests/excluded.js): this implementation deviates from the specification. It is run here all the same.") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<span class=\"why\">Cannot be served: 404 on todomvc.com itself</span></th><td class=\"n grey\" colspan=\"9\">not run</td>") != null);
    // GWT has no run yet: its row says so.
    try testing.expect(std.mem.indexOf(u8, h, "no run yet") != null);

    var app_out: Io.Writer.Allocating = .init(a);
    try writeApp(&app_out.writer, suites[0], .{});
    try testing.expect(std.mem.indexOf(u8, app_out.written(), "<code>examples/gwt/</code> is pinned by its sha256 <code>bbbbbbbbbbbbbbbb&hellip;</code>, checked at every fetch.") != null);
}

test "the Chrome column: a browser's run is kept apart from Crane's, shown beside it; a failure Chrome shares is marked" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const sha: [64]u8 = @splat('a');
    var suite = sampleTodoMvcSuite();
    suite.id = "react-todomvc";
    suite.framework = "react";
    suite.version = "19.2.5";
    const pass: journal.TestRecord = .{ .label = "crane-1", .crane_commit = "c", .console_sha256 = &sha, .framework = "react", .version = "19.2.5", .suite = "react-todomvc", .suite_kind = .todomvc_port, .source_sha256 = &sha, .page = "todomvc", .module = "New Todo", .name = "a", .id = "New Todo: a", .status = .PASS };
    var fail = pass;
    fail.id = "New Todo: b";
    fail.status = .FAIL;
    fail.message = "expected 2";
    var fail2 = fail;
    fail2.id = "New Todo: c";
    const page: journal.PageRecord = .{ .label = "crane-1", .crane_commit = "c", .console_sha256 = &sha, .framework = "react", .version = "19.2.5", .suite = "react-todomvc", .suite_kind = .todomvc_port, .source_sha256 = &sha, .page = "todomvc", .url = "u", .status = .OK, .wall_ms = 1000, .ran = 3, .records = 3, .exit = "exited with code 0" };
    // Chrome: a and b pass, c fails as in Crane.
    var c_pass = pass;
    c_pass.label = "chrome-1";
    c_pass.crane_commit = "none";
    c_pass.browser = "Chrome for Testing 157.0.8103.78";
    var c_b = c_pass;
    c_b.id = "New Todo: b";
    var c_c = c_pass;
    c_c.id = "New Todo: c";
    c_c.status = .FAIL;
    c_c.message = "expected 2";
    var c_page = page;
    c_page.label = "chrome-1";
    c_page.crane_commit = "none";
    c_page.browser = "Chrome for Testing 157.0.8103.78";
    const j: journal.Journal = .{ .tests = &.{ pass, fail, fail2, c_pass, c_b, c_c }, .pages = &.{ page, c_page } };
    const suites = try collect(a, .{ .suites = &.{suite} }, &.{j}, &.{});
    // One Crane run; Chrome's is apart.
    try testing.expectEqual(@as(usize, 1), suites[0].runs.len);
    try testing.expectEqual(@as(u32, 1), suites[0].runs[0].counts.pass);
    try testing.expectEqual(@as(u32, 2), suites[0].chrome.?.counts.pass);

    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(&out.writer, &.{}, null, suites, .{});
    try testing.expect(std.mem.indexOf(u8, out.written(), "<th class=\"n\">Chrome</th>") != null);
    try testing.expect(std.mem.indexOf(u8, out.written(), "run chrome-1: passed of run\">2 of 3</td>") != null);

    var app_out: Io.Writer.Allocating = .init(a);
    try writeApp(&app_out.writer, suites[0], .{});
    const h = app_out.written();
    try testing.expect(std.mem.indexOf(u8, h, "For comparison, Chrome for Testing 157.0.8103.78 ran the same page (run <code>chrome-1</code>): 2 passed of 3 run, 1 failed or errored.") != null);
    // c fails in both: marked; b fails in Crane only: not marked.
    const c_at = std.mem.indexOf(u8, h, "<tr><th>New Todo: c (Chrome fails it too)") orelse std.mem.indexOf(u8, h, "New Todo: c <span class=\"grey\">(Chrome fails it too)</span>");
    try testing.expect(c_at != null);
    try testing.expect(std.mem.indexOf(u8, h, "New Todo: b <span class=\"grey\">(Chrome fails it too)</span>") == null);
}

test "a Jasmine page: its unnamed passes and pending counted with its named failures; its Bazel target named as its server" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const sha: [64]u8 = @splat('a');
    var suite = sampleSuite();
    suite.id = "angular-jasmine";
    suite.framework = "angular";
    suite.title = "Angular";
    suite.version = "22.2.6";
    suite.reader = .jasmine_console;
    const fail: journal.TestRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "angular", .version = "22.2.6", .suite = "angular-jasmine", .suite_kind = .project, .source_sha256 = &sha, .page = "common-http-test", .module = "", .name = "HttpClient sends", .id = "HttpClient sends", .status = .FAIL, .message = "Expected 1 to be 2." };
    const page: journal.PageRecord = .{ .label = "l1", .crane_commit = "c", .console_sha256 = &sha, .framework = "angular", .version = "22.2.6", .suite = "angular-jasmine", .suite_kind = .project, .source_sha256 = &sha, .page = "common-http-test", .url = "u", .status = .OK, .wall_ms = 3000, .reported_total = 421, .reported_failed = 1, .ran = 1, .records = 1, .exit = "exited", .unnamed_passed = 418, .unnamed_pending = 2, .server = .{ .name = "web-test-runner manual mode", .bazel = "8.8.2", .bazel_lock_sha256 = &sha, .target = "//packages/common/http/test:test_web_debug" } };
    const suites = try collect(a, .{ .suites = &.{suite} }, &.{.{ .tests = &.{fail}, .pages = &.{page} }}, &.{});
    const c = suites[0].runs[0].counts;
    try testing.expectEqual(@as(u32, 418), c.pass);
    try testing.expectEqual(@as(u32, 1), c.fail);
    try testing.expectEqual(@as(u32, 2), c.project_skip);
    var out: Io.Writer.Allocating = .init(a);
    try writeFramework(&out.writer, .{ .id = "angular", .title = "Angular" }, suites, .{});
    const h = out.written();
    try testing.expect(std.mem.indexOf(u8, h, "run by the project&#39;s own Bazel 8.8.2 (its MODULE.bazel.lock sha256 <code>aaaaaaaaaaaaaaaa&hellip;</code>), one target per page.") != null);
    // The page's row counts its unnamed tests too: 419 run, 1 failed, 2 not run.
    try testing.expect(std.mem.indexOf(u8, h, "<td class=\"n\">419</td><td class=\"n fail\">1</td><td class=\"n grey\">0</td><td class=\"n grey\">2</td>") != null);
}

test "a suite's note is on its row and its page" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var suite = sampleSuite();
    suite.note = "No Chrome number yet.";
    const suites = try collect(a, .{ .suites = &.{suite} }, &.{}, &.{});
    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(&out.writer, &.{}, null, suites, .{});
    try testing.expect(std.mem.indexOf(u8, out.written(), "<span class=\"why\">No Chrome number yet.</span>") != null);
    var fw: Io.Writer.Allocating = .init(a);
    try writeFramework(&fw.writer, .{ .id = "htmx", .title = "htmx" }, suites, .{});
    try testing.expect(std.mem.indexOf(u8, fw.written(), "<p>No Chrome number yet.</p>") != null);
}

test "rate: one decimal, rounded; nothing run is a dash" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try rate(&out.writer, 1778, 1790);
    try rate(&out.writer, 0, 0);
    try testing.expectEqualStrings("99.3%&mdash;", out.written());
}
