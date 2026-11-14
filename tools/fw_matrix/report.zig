//! `fw_matrix report`: the JS framework compatibility matrix as finished
//! HTML, from journals only (tmp/plans/framework-matrix-plan.md, section 4).
//!
//!   <out>/index.html                 the overview, five numbered sections:
//!                                    1 the frameworks' own tests - per
//!                                      framework Crane's tests passed beside
//!                                      Chrome's and how many fail only in
//!                                      Crane; then those not run yet
//!                                    2 what fails in Crane and passes in
//!                                      Chrome, by cause (the manifest's
//!                                      `causes`), Chrome-only APIs apart
//!                                    3 TodoMVC: apps passing every test and
//!                                      tests passed in Crane and Chrome,
//!                                      every app in a closed list
//!                                    4 what is not run, and why - said once
//!                                    5 how this was measured (closed)
//!   <out>/<framework>/index.html     its figures, its Crane-only failures by
//!                                    cause, then (closed) those Chrome shares,
//!                                    what is not run, its pages and how it
//!                                    was measured
//!   <out>/todomvc/<app>/index.html   one TodoMVC app, the same way
//!
//! The redesign (lane fw1 b6; the user, 2026-11-14: "The data presentation
//! feels like noise and it isn't focusing on the important parts. I want
//! this page to be far easier for people to follow."): a visitor asks
//! whether a framework works in Crane, what fails in Crane that works in
//! Chrome, and what was not tested and why - in that order.
//!
//! The site's rules (tools/wpt_site/DESIGN.md, PRODUCT.md): every number is
//! in the HTML; site.js only enhances (it sorts every `table.listing` by its
//! cells' data-v / data-of); red is a failure, grey is blocking or not run;
//! Crane and Chrome side by side. It uses the WPT site's stylesheet and its
//! HTML helpers (tools/wpt_site/html.zig, by import). A TodoMVC app never
//! stands in for its framework's own suite: it is only in section 3.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const W = *Io.Writer;
const html = @import("site_html");
const journal = @import("journal.zig");
const manifest = @import("manifest.zig");
const exclusions = @import("exclusions.zig");

pub const Options = struct {
    /// Where the WPT site's site.css and site.js are, relative to <out>/
    /// ("../").
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
    /// The latest comparison run in a browser (`fw_matrix run --browser`,
    /// or a project runner's log read by `fw_matrix import`).
    chrome: ?Run = null,
};

/// What the TodoMVC port does not run of a test (it excludes no test):
/// tools/fw_matrix/excluded/todomvc-port.txt says the same.
pub const todomvc_port_note =
    "Crane's port runs every test of TodoMVC's app spec (cypress/e2e/spec.cy.js, 29 tests) on the app's unmodified build, driving it through DOM events as Cypress drives it. Of Cypress's own checks it does not run the parts that need layout: visibility is decided by computed style (no box, visibility, opacity) and not by size, clipping or transforms, and an action does not scroll the element into view or check that nothing covers it. Cypress's hooks that run before the app's own scripts have no in-page equivalent: an app counts as started when its page has loaded and its heading is visible, and the spec's spy on localStorage.setItem is installed then. Tests the spec itself skips for an app (its localStorage test for apps that keep no data there, the app's entries in tests/knownIssues.js) are reported as skipped by the app spec.";

/// Why rendering tests are not run: said once on the overview (section 4)
/// and once on a page that lists such tests.
pub const rendering_statement =
    "Crane draws nothing, so tests whose result depends on layout geometry or pixels are not run. Computed style, events, timers and animations do run.";

/// Where Node runs (the user, 2026-11-11 17:43 ET: "we can run node for the
/// purposes of these tests").
pub const node_note =
    "Node runs only the projects' own build steps, test servers and test runners, never inside Crane. jQuery's pages are served by its own test server (jquery-test-runner) with its own dependencies; Angular's are built by its own Bazel and served by its own web-test-runner, one target per page. htmx's test page and the TodoMVC apps are static files, served as they are.";

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
                    counts.fail += p.unnamed_failed orelse 0;
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

fn latest(s: SuiteRuns) ?Run {
    return if (s.runs.len == 0) null else s.runs[s.runs.len - 1];
}

// ============================================================================
// Crane's failures beside Chrome's
// ============================================================================

/// How a failure of Crane's compares with Chrome's run of the same page.
pub const Verdict = enum {
    /// Chrome's run passes it (or ran the tests of a page Crane stopped on).
    crane_only,
    /// Chrome's run fails it too (by name): not a Crane finding (lesson
    /// testing-a-framework-failure-chrome-shares-is-not-a-crane-finding.md).
    shared,
    /// No Chrome run of it to compare with.
    no_chrome,
};

/// One failure in a suite's latest Crane run: a failed or errored test, or
/// a page that stopped before naming any failing test.
pub const Failure = struct {
    test_rec: ?journal.TestRecord = null,
    page: ?journal.PageRecord = null,
    verdict: Verdict,
    /// Its cause, an index into the manifest's `causes`.
    cause: ?usize = null,
    /// A stopped page: the tests Chrome's run counted on it.
    chrome_tests: u32 = 0,
};

fn isFailing(t: journal.TestRecord) bool {
    return t.status == .FAIL or t.status.errored();
}

fn chromeFails(c: Run, id: []const u8) bool {
    for (c.tests) |t| if (std.mem.eql(u8, t.id, id) and isFailing(t)) return true;
    return false;
}

/// The tests Chrome's run counted on a page, or null when it has no such page.
fn chromePageTests(c: Run, page: []const u8) ?u32 {
    for (c.pages) |p| if (std.mem.eql(u8, p.page, page)) return p.reported_total orelse p.ran;
    return null;
}

fn matchesTest(mt: manifest.Match, s: manifest.Suite, t: journal.TestRecord) bool {
    if (mt.suite) |x| if (!std.mem.eql(u8, x, s.id)) return false;
    if (mt.page) |x| if (!std.mem.eql(u8, x, t.page)) return false;
    if (mt.id_contains) |x| if (std.mem.indexOf(u8, t.id, x) == null) return false;
    if (mt.message_contains) |x| if (t.message == null or std.mem.indexOf(u8, t.message.?, x) == null) return false;
    return true;
}

fn matchesPage(mt: manifest.Match, s: manifest.Suite, p: journal.PageRecord) bool {
    if (mt.id_contains != null) return false;
    if (mt.page == null and mt.message_contains == null) return false;
    if (mt.suite) |x| if (!std.mem.eql(u8, x, s.id)) return false;
    if (mt.page) |x| if (!std.mem.eql(u8, x, p.page)) return false;
    if (mt.message_contains) |x| if (p.message == null or std.mem.indexOf(u8, p.message.?, x) == null) return false;
    return true;
}

fn causeOf(causes: []const manifest.Cause, s: manifest.Suite, f: Failure) ?usize {
    for (causes, 0..) |c, i| for (c.covers) |mt| {
        if (f.test_rec) |t| {
            if (matchesTest(mt, s, t)) return i;
        } else if (f.page) |p| {
            if (matchesPage(mt, s, p)) return i;
        }
    };
    return null;
}

/// A suite's failures in its latest Crane run, each beside Chrome's run.
pub fn failuresOf(arena: Allocator, causes: []const manifest.Cause, s: SuiteRuns) ![]const Failure {
    const r = latest(s) orelse return &.{};
    var out: std.ArrayList(Failure) = .empty;
    for (r.tests) |t| if (isFailing(t)) {
        var f: Failure = .{ .test_rec = t, .verdict = if (s.chrome) |c| (if (chromeFails(c, t.id)) .shared else .crane_only) else .no_chrome };
        f.cause = causeOf(causes, s.suite, f);
        try out.append(arena, f);
    };
    for (r.pages) |p| if (p.status != .OK) {
        // A page whose failing tests are named is counted through them.
        const named = for (r.tests) |t| {
            if (std.mem.eql(u8, t.page, p.page) and isFailing(t)) break true;
        } else false;
        if (named) continue;
        var f: Failure = .{ .page = p, .verdict = .no_chrome };
        if (s.chrome) |c| if (chromePageTests(c, p.page)) |n| {
            f.verdict = if (n > 0) .crane_only else .shared;
            f.chrome_tests = n;
        };
        f.cause = causeOf(causes, s.suite, f);
        try out.append(arena, f);
    };
    return out.items;
}

const Tally = struct {
    tests: u32 = 0,
    pages: u32 = 0,

    fn of(fs: []const Failure, v: Verdict) Tally {
        var t: Tally = .{};
        for (fs) |f| if (f.verdict == v) {
            if (f.test_rec != null) t.tests += 1 else t.pages += 1;
        };
        return t;
    }

    fn total(t: Tally) u32 {
        return t.tests + t.pages;
    }
};

/// Failures Chrome's run counted without naming them.
fn chromeUnnamedFailures(s: SuiteRuns) u32 {
    const c = s.chrome orelse return 0;
    var n: u32 = 0;
    for (c.pages) |p| n += p.unnamed_failed orelse 0;
    return n;
}

/// Every test of the run passed and every page ended normally.
fn allPass(r: Run) bool {
    if (r.counts.ran() == 0 or r.counts.fail > 0 or r.counts.errored() > 0) return false;
    for (r.pages) |p| if (p.status != .OK) return false;
    return true;
}

// ============================================================================
// Pieces
// ============================================================================

/// Passed over run, one decimal; never "100.0%" unless every test passed.
fn rate(w: W, pass: u32, ran: u32) !void {
    if (ran == 0) return w.writeAll("&mdash;");
    const tenths = (@as(u64, pass) * 1000 + ran / 2) / ran;
    if (pass < ran and tenths == 1000) return w.writeAll("&gt;99.9%");
    if (pass > 0 and tenths == 0) return w.writeAll("&lt;0.1%");
    try w.print("{d}.{d}%", .{ tenths / 10, tenths % 10 });
}

/// "<b>1,066</b> / 1,072" and its share, in a cell site.js sorts by share.
fn passCell(w: W, c: journal.Counts, label: []const u8) !void {
    try w.print("<td class=\"n\" data-label=\"{s}\" data-v=\"{d}\" data-of=\"{d}\"><b>", .{ label, c.pass, c.ran() });
    try html.num(w, c.pass);
    try w.writeAll("</b> / ");
    try html.num(w, c.ran());
    try w.writeAll(" <span class=\"pct\">");
    try rate(w, c.pass, c.ran());
    try w.writeAll("</span></td>");
}

/// A stacked bar of one run's tests: passed (green), failed and errored
/// (red), not run (grey), each a share of all its tests.
fn meter(w: W, c: journal.Counts) !void {
    const parts = [_]struct { u32, []const u8, []const u8 }{
        .{ c.pass, "var(--pass)", "passed" },
        .{ c.fail + c.errored(), "var(--fail)", "failed or errored" },
        .{ c.rendering + c.not_run + c.project_skip, "var(--block-seg)", "not run" },
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
    try w.writeAll("</div>\n");
}

fn head(w: W, title: []const u8, description: []const u8, o: Options, depth: u32) !void {
    try w.writeAll("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n<title>");
    try html.text(w, title);
    try w.writeAll("</title>\n<meta name=\"description\" content=\"");
    try html.text(w, description);
    try w.writeAll("\">\n<meta name=\"color-scheme\" content=\"light dark\">\n<link rel=\"stylesheet\" href=\"");
    for (0..depth) |_| try w.writeAll("../");
    try w.print("{s}site.css\">\n<link rel=\"icon\" href=\"data:,\">\n<script src=\"", .{o.assets});
    for (0..depth) |_| try w.writeAll("../");
    try w.print("{s}site.js\" defer></script>\n", .{o.assets});
    try w.writeAll(style);
    try w.writeAll("</head>\n<body>\n<main class=\"doc fw\" id=\"main\">\n");
}

const style =
    \\<style>
    \\.fw .fw-sec { margin: 0 0 3rem; padding-top: 1.4rem; border-top: 1px solid var(--rule); }
    \\.fw .lede, .fw .fw-facts, .fw .fw-sec > p { max-width: var(--measure); }
    \\.fw h3 { margin: 1.8rem 0 0.5rem; font: 600 1.15rem/1.3 var(--serif); }
    \\.fw .ver { margin-left: 0.35rem; font: 400 0.84rem/1.3 var(--sans); color: var(--ink-2); }
    \\.fw .pct { display: inline-block; min-width: 3.4rem; margin-left: 0.4rem; font-size: 0.8rem; color: var(--ink-2); }
    \\.fw .listing tbody th { width: auto; }
    \\.fw .listing td.msg pre { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; font: 400 0.78rem/1.45 var(--mono); }
    \\.fw .listing td a.fail { color: var(--fail); }
    \\.fw .tag { margin-left: 0.5rem; font: 600 0.7rem/1 var(--sans); letter-spacing: 0.05em; text-transform: uppercase; color: var(--ink-2); white-space: nowrap; }
    \\.fw .back-link { margin: 0 0 0.8rem; font: 500 0.9rem/1.4 var(--sans); }
    \\.fw .order, .fw .fine { margin: 0.6rem 0 0; max-width: var(--measure); font: 400 0.84rem/1.45 var(--sans); color: var(--ink-2); }
    \\.fw .fw-facts { margin: 1rem 0; padding-left: 1.2rem; }
    \\.fw .fw-facts li { margin: 0 0 0.45rem; }
    \\.fw table.versus { max-width: 34rem; margin: 1rem 0; }
    \\.fw details.fw-more { margin: 0.8rem 0 0; }
    \\.fw details.fw-more > summary { cursor: pointer; padding: 0.35rem 0; font: 600 0.92rem/1.4 var(--sans); color: var(--link); }
    \\.fw details.fw-more[open] > summary { margin-bottom: 0.6rem; }
    \\.fw .meter { max-width: 34rem; }
    \\.fw .method { max-width: var(--measure); padding-left: 1.2rem; }
    \\.fw .method li { margin: 0 0 0.6rem; }
    \\@media (max-width: 52rem) {
    \\  .fw .listing tbody td:nth-child(n) { display: block; grid-column: 1 / -1; text-align: left; white-space: normal; }
    \\  .fw .listing tbody td[data-label]::before { content: attr(data-label) ": "; font: 400 0.78rem/1.3 var(--sans); color: var(--ink-2); }
    \\}
    \\</style>
    \\
;

const page_foot = "<footer class=\"foot\"><p>Written as HTML by <code>tools/fw_matrix</code> from its journals (<code>crane-fw/1</code>).</p></footer>\n</main>\n</body>\n</html>\n";

/// A numbered section's heading.
fn sectionHead(w: W, n: u32, id: []const u8, title: []const u8) !void {
    try w.print("<section class=\"fw-sec\" id=\"{s}\" aria-labelledby=\"{s}-h\">\n<h2 id=\"{s}-h\"><span class=\"secno\">{d}</span>", .{ id, id, id, n });
    try html.text(w, title);
    try w.print("<a class=\"self\" href=\"#{s}\" aria-label=\"Link to section {d}\">&para;</a></h2>\n", .{ id, n });
}

/// Where a suite's page is, below the overview: a framework's own suites at
/// "<framework>/", a TodoMVC app at "todomvc/<app>/".
pub fn pageDir(s: manifest.Suite) [2][]const u8 {
    return switch (s.kind) {
        .project => .{ "", s.framework },
        .todomvc_port => .{ "todomvc/", s.framework },
    };
}

/// The overview's first section: the listed frameworks, or (a manifest
/// without that list) one per framework a project suite names.
fn frameworkList(arena: Allocator, m: manifest.Manifest) ![]const manifest.Framework {
    if (m.frameworks.len > 0) return m.frameworks;
    var out: std.ArrayList(manifest.Framework) = .empty;
    for (m.suites) |s| {
        if (s.kind != .project) continue;
        for (out.items) |fw| {
            if (std.mem.eql(u8, fw.id, s.framework)) break;
        } else try out.append(arena, .{ .id = s.framework, .title = s.title });
    }
    return out.items;
}

fn byTitle(_: void, a: manifest.Framework, b: manifest.Framework) bool {
    return std.ascii.lessThanIgnoreCase(a.title, b.title);
}

fn hasSuite(suites: []const SuiteRuns, fw: manifest.Framework) bool {
    for (suites) |s| if (s.suite.kind == .project and std.mem.eql(u8, s.suite.framework, fw.id)) return true;
    return false;
}

/// A suite's name where it is listed: its framework's, or "TodoMVC <app>".
fn suiteName(w: W, s: manifest.Suite) !void {
    if (s.kind == .todomvc_port) try w.writeAll("TodoMVC ");
    try html.text(w, s.title);
}

/// The link to a suite's Crane-only failures, from the overview.
fn suiteHref(w: W, s: manifest.Suite) !void {
    const dir = pageDir(s);
    try html.href(w, dir[0]);
    try html.href(w, dir[1]);
    try w.writeAll("/#fails-only");
}

/// "3 tests", "2 tests and 1 page".
fn tallyText(w: W, t: Tally) !void {
    if (t.tests > 0 or t.pages == 0) try html.plural(w, t.tests, "test", "tests");
    if (t.tests > 0 and t.pages > 0) try w.writeAll(" and ");
    if (t.pages > 0) try html.plural(w, t.pages, "page", "pages");
}

// ============================================================================
// The overview
// ============================================================================

pub fn writeIndex(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns, o: Options) !void {
    try head(w, "Crane: JavaScript frameworks", "JavaScript frameworks' own browser tests, and the TodoMVC apps, run in Crane and in Chrome: what passes, what fails only in Crane, and what is not run and why.", o, 0);
    const failures = try arena.alloc([]const Failure, suites.len);
    for (suites, 0..) |s, i| failures[i] = try failuresOf(arena, m.causes, s);

    try w.writeAll("<header class=\"head\">\n<h1>Crane <span class=\"h1-rest\">JavaScript frameworks</span></h1>\n<p class=\"subtitle\">Do JavaScript frameworks work in Crane? Each framework&#39;s own browser tests, run in Crane and in Chrome, and the TodoMVC apps built with them.</p>\n<dl class=\"head-meta\">\n");
    try runsMeta(arena, w, suites);
    try w.writeAll("<div><dt>More</dt><dd><a href=\"../\">Crane&#39;s web-platform-tests results</a></dd></div>\n</dl>\n</header>\n");

    const all = try frameworkList(arena, m);
    var running: std.ArrayList(manifest.Framework) = .empty;
    var waiting: std.ArrayList(manifest.Framework) = .empty;
    for (all) |fw| try (if (hasSuite(suites, fw)) &running else &waiting).append(arena, fw);
    std.mem.sort(manifest.Framework, running.items, {}, byTitle);
    std.mem.sort(manifest.Framework, waiting.items, {}, byTitle);

    var n: u32 = 0;
    // 1. The frameworks' own tests.
    n += 1;
    try sectionHead(w, n, "own", "The frameworks' own tests");
    try w.writeAll("<p class=\"lede\">Each framework&#39;s own browser tests, run in Crane the way the project runs them in a browser (its own build, test server and test runner), and in Chrome by the project&#39;s own runner. A test that fails in both says nothing about Crane; the last column counts the tests that fail only in Crane.</p>\n");
    try w.writeAll("<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">Framework</th><th scope=\"col\" class=\"n\">Crane: tests passed</th><th scope=\"col\" class=\"n\">Chrome: tests passed</th><th scope=\"col\" class=\"n\">Fail only in Crane</th></tr></thead>\n<tbody>\n");
    for (running.items) |fw| for (suites, 0..) |s, si| {
        if (s.suite.kind != .project or !std.mem.eql(u8, s.suite.framework, fw.id)) continue;
        try frameworkRow(w, fw, s, failures[si]);
    };
    try w.writeAll("</tbody>\n</table>\n");
    if (waiting.items.len > 0) {
        try w.writeAll("<h3 id=\"waiting\">Not run yet</h3>\n<p>Their browser tests run only through a test runner that drives the browser over a protocol Crane does not speak yet; section 4 says which and why.</p>\n<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">Framework</th><th scope=\"col\" class=\"n\">Its own browser tests</th><th scope=\"col\">Waits for</th></tr></thead>\n<tbody>\n");
        for (waiting.items) |fw| try waitingRow(w, fw);
        try w.writeAll("</tbody>\n</table>\n");
    }
    try w.writeAll("<p class=\"order\">Order: the frameworks Crane runs, then those not run yet; each group A to Z. With script on, a column head sorts its table.</p>\n</section>\n");

    // 2. What fails in Crane and passes in Chrome.
    n += 1;
    try sectionHead(w, n, "gaps", "What fails in Crane and passes in Chrome");
    try writeCauses(arena, w, m, suites, failures);
    try w.writeAll("</section>\n");

    // 3. TodoMVC.
    var any_app = m.todomvc != null;
    for (suites) |s| any_app = any_app or s.suite.kind == .todomvc_port;
    if (any_app) {
        n += 1;
        try sectionHead(w, n, "todomvc", "TodoMVC: apps built with each framework");
        try writeTodoMvc(arena, w, m, suites, failures);
        try w.writeAll("</section>\n");
    }

    // 4. What is not run, and why: said once.
    n += 1;
    try sectionHead(w, n, "not-run", "What is not run, and why");
    try writeNotRun(arena, w, m, suites, waiting.items);
    try w.writeAll("</section>\n");

    // 5. How this was measured.
    n += 1;
    try sectionHead(w, n, "method", "How this was measured");
    try w.writeAll("<details class=\"fw-more\"><summary>The runs, the browsers, the pins and the method</summary>\n<ul class=\"method\">\n");
    try w.writeAll("<li>Each page is opened in Crane&#39;s console as a user opens it, and read from the test framework&#39;s own report; Chrome&#39;s numbers come from the same pages, or from the project&#39;s own runner where the project runs its tests that way (each suite below says which).</li>\n");
    for (running.items) |fw| for (suites) |s| {
        if (s.suite.kind != .project or !std.mem.eql(u8, s.suite.framework, fw.id)) continue;
        try w.writeAll("<li>");
        try suiteMethod(w, s);
        try w.writeAll("</li>\n");
    };
    if (m.todomvc) |t| {
        try w.writeAll("<li>TodoMVC: the apps of <a href=\"");
        try html.text(w, t.repository);
        try w.writeAll("\">tastejs/todomvc</a> at <code>");
        try html.text(w, t.commit[0..@min(12, t.commit.len)]);
        try w.writeAll("</code>, each <code>examples/&lt;app&gt;/</code> pinned by its sha256 and checked at every fetch; each app&#39;s page names its runs. ");
        try html.text(w, todomvc_port_note);
        try w.writeAll("</li>\n");
    }
    try w.writeAll("</ul>\n</details>\n</section>\n");
    try w.writeAll(page_foot);
}

/// The header's "Crane" and "Chrome" rows: the commits and browsers of the
/// runs shown, each with what it ran.
fn runsMeta(arena: Allocator, w: W, suites: []const SuiteRuns) !void {
    const Group = struct { key: []const u8, names: std.ArrayList([]const u8) = .empty };
    for ([_]bool{ false, true }) |browser| {
        var groups: std.ArrayList(Group) = .empty;
        for (suites) |s| {
            const r = (if (browser) s.chrome else latest(s)) orelse continue;
            const key = if (browser) r.browser.? else r.crane_commit;
            const name = if (s.suite.kind == .todomvc_port) "TodoMVC" else s.suite.title;
            const g = for (groups.items) |*gp| {
                if (std.mem.eql(u8, gp.key, key)) break gp;
            } else blk: {
                try groups.append(arena, .{ .key = key });
                break :blk &groups.items[groups.items.len - 1];
            };
            for (g.names.items) |x| {
                if (std.mem.eql(u8, x, name)) break;
            } else try g.names.append(arena, name);
        }
        if (groups.items.len == 0) continue;
        try w.writeAll(if (browser) "<div><dt>Chrome</dt><dd>" else "<div><dt>Crane</dt><dd>");
        for (groups.items, 0..) |g, i| {
            if (i > 0) try w.writeAll("; ");
            if (browser) try html.text(w, g.key) else {
                try w.writeAll("<code>");
                try html.text(w, g.key);
                try w.writeAll("</code>");
            }
            try w.writeAll(" (");
            for (g.names.items, 0..) |x, k| {
                if (k > 0) try w.writeAll(", ");
                try html.text(w, x);
            }
            try w.writeAll(")");
        }
        try w.writeAll("</dd></div>\n");
    }
}

fn frameworkRow(w: W, fw: manifest.Framework, s: SuiteRuns, fs: []const Failure) !void {
    try w.writeAll("<tr id=\"fw-");
    try html.text(w, fw.id);
    try w.writeAll("\"><th scope=\"row\"><a href=\"");
    try html.href(w, fw.id);
    try w.writeAll("/\">");
    try html.text(w, fw.title);
    try w.writeAll("</a><span class=\"ver\">");
    try html.text(w, s.suite.version);
    try w.writeAll("</span></th>");
    const r = latest(s) orelse {
        try w.writeAll("<td class=\"n\" data-label=\"Crane\">no run yet</td><td class=\"n\" data-label=\"Chrome\"></td><td class=\"n\" data-label=\"Fail only in Crane\"></td></tr>\n");
        return;
    };
    try passCell(w, r.counts, "Crane");
    if (s.chrome) |c| try passCell(w, c.counts, "Chrome") else try w.writeAll("<td class=\"n quiet\" data-label=\"Chrome\">no Chrome run yet</td>");
    // The verdict: what fails only in Crane, or, with no Chrome run, what
    // fails at all.
    const v: Verdict = if (s.chrome != null) .crane_only else .no_chrome;
    const t = Tally.of(fs, v);
    try w.print("<td class=\"n\" data-label=\"Fail only in Crane\" data-v=\"{d}\">", .{t.total()});
    if (t.total() == 0) {
        try w.writeAll("<span class=\"quiet\">none</span></td></tr>\n");
        return;
    }
    try w.writeAll("<a class=\"fail\" href=\"");
    try suiteHref(w, s.suite);
    try w.writeAll("\">");
    try tallyText(w, t);
    try w.writeAll("</a>");
    if (v == .no_chrome) try w.writeAll(" <span class=\"quiet\">(no Chrome run to compare)</span>");
    try w.writeAll("</td></tr>\n");
}

/// The protocol a waiting framework needs: CDP when any of its suites needs
/// only CDP, else CDP or WebDriver BiDi.
fn neededProtocol(fw: manifest.Framework) ?manifest.Protocol {
    var p: ?manifest.Protocol = null;
    for (fw.not_run) |nr| if (nr.waits_for) |x| {
        if (x == .cdp or p == null) p = x;
    };
    return p;
}

fn waitingRow(w: W, fw: manifest.Framework) !void {
    try w.writeAll("<tr id=\"fw-");
    try html.text(w, fw.id);
    try w.writeAll("\"><th scope=\"row\"><a href=\"");
    try html.href(w, fw.id);
    try w.writeAll("/\">");
    try html.text(w, fw.title);
    try w.writeAll("</a>");
    if (fw.not_run.len > 0) {
        try w.writeAll("<span class=\"ver\">");
        try html.text(w, fw.not_run[0].version);
        try w.writeAll("</span>");
    }
    try w.writeAll("</th>");
    var counted: u32 = 0;
    var uncounted = false;
    for (fw.not_run) |nr| {
        if (nr.tests) |t| counted += t else uncounted = true;
    }
    if (counted > 0) {
        try w.print("<td class=\"n\" data-label=\"Its own browser tests\" data-v=\"{d}\">", .{counted});
        try html.plural(w, counted, "test", "tests");
        if (uncounted) try w.writeAll(" and more, not counted");
    } else try w.writeAll("<td class=\"n quiet\" data-label=\"Its own browser tests\">not counted");
    try w.writeAll("</td><td data-label=\"Waits for\">");
    if (neededProtocol(fw)) |p| try html.text(w, p.short()) else try w.writeAll("&mdash;");
    try w.writeAll("</td></tr>\n");
}

/// Cause indices, the most failures first; ties keep the manifest's order.
fn causeOrder(arena: Allocator, totals: []const u32) ![]usize {
    const order = try arena.alloc(usize, totals.len);
    for (order, 0..) |*o, i| o.* = i;
    std.mem.sort(usize, order, totals, struct {
        fn lt(t: []const u32, a: usize, b: usize) bool {
            if (t[a] != t[b]) return t[a] > t[b];
            return a < b;
        }
    }.lt);
    return order;
}

/// Section 2: the failures Crane has and Chrome does not, by cause.
fn writeCauses(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns, failures: []const []const Failure) !void {
    const Entry = struct { suite: usize, tally: Tally = .{}, chrome_tests: u32 = 0, no_chrome: bool };
    const Group = struct { entries: std.ArrayList(Entry) = .empty, tally: Tally = .{} };
    const groups = try arena.alloc(Group, m.causes.len);
    for (groups) |*g| g.* = .{};
    var unsorted: std.ArrayList(struct { usize, Failure }) = .empty;
    for (failures, 0..) |fs, si| for (fs) |f| {
        if (f.verdict == .shared) continue;
        const ci = f.cause orelse {
            try unsorted.append(arena, .{ si, f });
            continue;
        };
        const g = &groups[ci];
        const e = for (g.entries.items) |*ep| {
            if (ep.suite == si) break ep;
        } else blk: {
            try g.entries.append(arena, .{ .suite = si, .no_chrome = f.verdict == .no_chrome });
            break :blk &g.entries.items[g.entries.items.len - 1];
        };
        if (f.test_rec != null) {
            e.tally.tests += 1;
            g.tally.tests += 1;
        } else {
            e.tally.pages += 1;
            g.tally.pages += 1;
            e.chrome_tests += f.chrome_tests;
        }
    };
    // Each cause's places: the frameworks' own suites, then the apps, A to Z.
    for (groups) |*g| std.mem.sort(Entry, g.entries.items, suites, struct {
        fn lt(ss: []const SuiteRuns, x: Entry, y: Entry) bool {
            const a = ss[x.suite].suite;
            const b = ss[y.suite].suite;
            if (a.kind != b.kind) return a.kind == .project;
            return std.ascii.lessThanIgnoreCase(a.title, b.title);
        }
    }.lt);
    // The lede: the real gaps' totals.
    var gaps: u32 = 0;
    var total: Tally = .{};
    var where: std.ArrayList(usize) = .empty;
    for (m.causes, groups) |c, g| {
        if (c.kind != .crane_gap or g.tally.total() == 0) continue;
        gaps += 1;
        total.tests += g.tally.tests;
        total.pages += g.tally.pages;
        for (g.entries.items) |e| {
            for (where.items) |x| {
                if (x == e.suite) break;
            } else try where.append(arena, e.suite);
        }
    }
    if (gaps == 0 and unsorted.items.len == 0) {
        try w.writeAll("<p>Nothing: every test that fails in Crane fails in Chrome too.</p>\n");
    } else {
        var projects: u32 = 0;
        var apps: u32 = 0;
        for (where.items) |si| {
            if (suites[si].suite.kind == .project) projects += 1 else apps += 1;
        }
        try w.writeAll("<p class=\"lede\">");
        try html.plural(w, gaps, "cause", "causes");
        try w.writeAll(": ");
        try tallyText(w, total);
        try w.writeAll(", in ");
        try html.plural(w, projects, "framework&#39;s own tests", "frameworks&#39; own tests");
        if (apps > 0) {
            try w.writeAll(" and ");
            try html.plural(w, apps, "TodoMVC app", "TodoMVC apps");
        }
        try w.writeAll(". A test is here when it fails in Crane and Chrome&#39;s run of the same page passes it; a page is here when it stops in Crane before any test runs and Chrome runs its tests. A test with no Chrome run to compare is marked. Largest first; each links to its tests and their messages.</p>\n");
    }
    const totals = try arena.alloc(u32, groups.len);
    for (groups, totals) |g, *t| t.* = g.tally.total();
    const order = try causeOrder(arena, totals);
    for ([_]manifest.CauseKind{ .crane_gap, .chrome_only_api }) |kind| {
        var any = false;
        for (order) |ci| {
            const c = m.causes[ci];
            const g = groups[ci];
            if (c.kind != kind or g.tally.total() == 0) continue;
            if (!any) {
                if (kind == .chrome_only_api) try w.writeAll("<h3 id=\"chrome-only\">Chrome-only APIs (not standards yet)</h3>\n<p>These fail because Crane does not have an API that only Chrome ships and that is not a web standard yet. They are not counted as Crane gaps above.</p>\n");
                try w.writeAll("<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">Cause</th><th scope=\"col\" class=\"n\">Tests</th><th scope=\"col\">Where</th></tr></thead>\n<tbody>\n");
                any = true;
            }
            try w.writeAll("<tr><th scope=\"row\">");
            try html.text(w, c.title);
            try w.print("</th><td class=\"n\" data-label=\"Tests\" data-v=\"{d}\">", .{g.tally.total()});
            try tallyText(w, g.tally);
            try w.writeAll("</td><td data-label=\"Where\">");
            for (g.entries.items, 0..) |e, k| {
                if (k > 0) try w.writeAll(", ");
                const s = suites[e.suite].suite;
                try w.writeAll("<a href=\"");
                try suiteHref(w, s);
                try w.writeAll("\">");
                try suiteName(w, s);
                try w.writeByte(' ');
                if (e.tally.tests > 0) try html.num(w, e.tally.tests);
                if (e.tally.tests > 0 and e.tally.pages > 0) try w.writeAll(" and ");
                if (e.tally.pages > 0) try html.plural(w, e.tally.pages, "page", "pages");
                try w.writeAll("</a>");
                if (e.tally.pages > 0 and e.chrome_tests > 0) {
                    try w.writeAll(" <span class=\"quiet\">(Chrome runs ");
                    try html.plural(w, e.chrome_tests, "test", "tests");
                    try w.writeAll(" there)</span>");
                }
                if (e.no_chrome) try w.writeAll(" <span class=\"quiet\">(no Chrome run to compare)</span>");
            }
            try w.writeAll("</td></tr>\n");
        }
        if (any) try w.writeAll("</tbody>\n</table>\n");
    }
    if (unsorted.items.len > 0) {
        try w.writeAll("<h3 id=\"unsorted\">Not yet sorted by cause</h3>\n<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">Test</th><th scope=\"col\">Where</th><th scope=\"col\">First failing assertion</th></tr></thead>\n<tbody>\n");
        for (unsorted.items) |u| {
            const s = suites[u[0]].suite;
            const f = u[1];
            try w.writeAll("<tr><th scope=\"row\">");
            if (f.test_rec) |t| try html.text(w, t.id) else try html.text(w, f.page.?.page);
            try w.writeAll("</th><td data-label=\"Where\"><a href=\"");
            try suiteHref(w, s);
            try w.writeAll("\">");
            try suiteName(w, s);
            try w.writeAll("</a>");
            if (f.verdict == .no_chrome) try w.writeAll(" <span class=\"quiet\">(no Chrome run to compare)</span>");
            try w.writeAll("</td><td class=\"msg\"><pre>");
            const msg = if (f.test_rec) |t| t.message orelse "" else f.page.?.message orelse "";
            try html.text(w, msg[0..@min(msg.len, 300)]);
            try w.writeAll("</pre></td></tr>\n");
        }
        try w.writeAll("</tbody>\n</table>\n");
    }
    // A Chrome run that failed tests it does not name: they may be among
    // the Crane-only ones.
    for (suites, failures) |s, fs| {
        const unnamed = chromeUnnamedFailures(s);
        const t = Tally.of(fs, .crane_only);
        if (unnamed == 0 or t.tests == 0) continue;
        try w.writeAll("<p class=\"fine\">");
        try suiteName(w, s.suite);
        try w.writeAll(": Chrome&#39;s own run failed ");
        try html.plural(w, unnamed, "test", "tests");
        try w.writeAll(" that its output does not name; ");
        try w.writeAll(if (unnamed == 1) "it" else "they");
        try w.writeAll(" may be among the ");
        try html.num(w, t.tests);
        try w.writeAll(" counted here.</p>\n");
    }
}

/// Section 3: TodoMVC in a few numbers, every app in a closed list.
fn writeTodoMvc(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns, failures: []const []const Failure) !void {
    var apps: u32 = 0;
    var crane_all: u32 = 0;
    var chrome_all: u32 = 0;
    var crane: journal.Counts = .{};
    var chrome: journal.Counts = .{};
    var crane_only: u32 = 0;
    var shared: u32 = 0;
    var only_apps: std.ArrayList(struct { usize, u32 }) = .empty;
    var chrome_only: std.ArrayList(struct { usize, []const u8 }) = .empty;
    // Every list here is A to Z by app.
    var order: std.ArrayList(usize) = .empty;
    for (suites, 0..) |s, si| if (s.suite.kind == .todomvc_port) try order.append(arena, si);
    std.mem.sort(usize, order.items, suites, struct {
        fn lt(ss: []const SuiteRuns, a: usize, b: usize) bool {
            return std.ascii.lessThanIgnoreCase(ss[a].suite.title, ss[b].suite.title);
        }
    }.lt);
    for (order.items) |si| {
        const s = suites[si];
        apps += 1;
        if (latest(s)) |r| {
            crane.merge(r.counts);
            if (allPass(r)) crane_all += 1;
            if (s.chrome) |c| for (c.tests) |ct| if (isFailing(ct)) {
                for (r.tests) |t| if (std.mem.eql(u8, t.id, ct.id) and t.status == .PASS) {
                    try chrome_only.append(arena, .{ si, ct.id });
                    break;
                };
            };
        }
        if (s.chrome) |c| {
            chrome.merge(c.counts);
            if (allPass(c)) chrome_all += 1;
        }
        const t = Tally.of(failures[si], .crane_only);
        crane_only += t.total();
        shared += Tally.of(failures[si], .shared).total();
        if (t.total() > 0) try only_apps.append(arena, .{ si, t.total() });
    }
    var not_served: u32 = 0;
    if (m.todomvc) |t| for (t.apps) |app| {
        not_served += @intFromBool(app.not_served != null);
    };
    try w.writeAll("<p class=\"lede\">The apps todomvc.com lists, each the app&#39;s unmodified build, checked by Crane&#39;s port of TodoMVC&#39;s app spec (29 tests per app). They measure an app written with a framework, not the framework&#39;s own tests.</p>\n");
    try w.writeAll("<table class=\"versus\">\n<thead><tr><th scope=\"col\"></th><th scope=\"col\" class=\"n\">Crane</th><th scope=\"col\" class=\"n\">Chrome</th></tr></thead>\n<tbody>\n");
    try w.writeAll("<tr><th scope=\"row\">Apps that pass every test</th><td class=\"n\"><b>");
    try html.num(w, crane_all);
    try w.writeAll("</b> / ");
    try html.num(w, apps);
    try w.writeAll("</td><td class=\"n\"><b>");
    try html.num(w, chrome_all);
    try w.writeAll("</b> / ");
    try html.num(w, apps);
    try w.writeAll("</td></tr>\n<tr><th scope=\"row\">Tests passed</th><td class=\"n\"><b>");
    try html.num(w, crane.pass);
    try w.writeAll("</b> / ");
    try html.num(w, crane.ran());
    try w.writeAll("</td><td class=\"n\"><b>");
    try html.num(w, chrome.pass);
    try w.writeAll("</b> / ");
    try html.num(w, chrome.ran());
    try w.writeAll("</td></tr>\n</tbody>\n</table>\n<ul class=\"fw-facts\">\n<li><b class=\"fail\">");
    try html.num(w, crane_only);
    try w.writeAll("</b> ");
    try w.writeAll(if (crane_only == 1) "test fails" else "tests fail");
    try w.writeAll(" only in Crane");
    if (only_apps.items.len > 0) {
        try w.writeAll(", in ");
        try html.plural(w, only_apps.items.len, "app", "apps");
        try w.writeAll(": ");
        for (only_apps.items, 0..) |x, i| {
            if (i > 0) try w.writeAll(", ");
            try w.writeAll("<a href=\"");
            try suiteHref(w, suites[x[0]].suite);
            try w.writeAll("\">");
            try html.text(w, suites[x[0]].suite.title);
            try w.print(" {d}</a>", .{x[1]});
        }
        try w.writeAll(" (their causes are in <a href=\"#gaps\">section 2</a>)");
    }
    try w.writeAll(".</li>\n<li><b>");
    try html.num(w, chrome_only.items.len);
    try w.writeAll("</b> ");
    try w.writeAll(if (chrome_only.items.len == 1) "test fails" else "tests fail");
    try w.writeAll(" only in Chrome");
    for (chrome_only.items, 0..) |x, i| {
        try w.writeAll(if (i == 0) ": " else "; ");
        try html.text(w, suites[x[0]].suite.title);
        try w.writeAll(" &ldquo;");
        try html.text(w, x[1]);
        try w.writeAll("&rdquo;");
    }
    try w.writeAll(".</li>\n<li><b>");
    try html.num(w, shared);
    try w.writeAll("</b> ");
    try w.writeAll(if (shared == 1) "test fails" else "tests fail");
    try w.writeAll(" in Chrome too, so they say nothing about Crane; each app&#39;s page lists them.</li>\n</ul>\n");

    try w.print("<details class=\"fw-more\" id=\"apps\"><summary>All {d} apps, A to Z</summary>\n", .{apps});
    try w.writeAll("<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">App</th><th scope=\"col\" class=\"n\">Crane: tests passed</th><th scope=\"col\" class=\"n\">Chrome: tests passed</th><th scope=\"col\" class=\"n\">Fail only in Crane</th></tr></thead>\n<tbody>\n");
    for (order.items) |si| {
        const s = suites[si];
        try w.writeAll("<tr id=\"app-");
        try html.text(w, s.suite.framework);
        try w.writeAll("\"><th scope=\"row\"><a href=\"todomvc/");
        try html.href(w, s.suite.framework);
        try w.writeAll("/\">");
        try html.text(w, s.suite.title);
        try w.writeAll("</a>");
        if (s.suite.app) |app| if (app.version) |v| {
            try w.writeAll("<span class=\"ver\">");
            try html.text(w, v);
            try w.writeAll("</span>");
        };
        try w.writeAll("</th>");
        if (latest(s)) |r| try passCell(w, r.counts, "Crane") else try w.writeAll("<td class=\"n quiet\" data-label=\"Crane\">no run yet</td>");
        if (s.chrome) |c| try passCell(w, c.counts, "Chrome") else try w.writeAll("<td class=\"n quiet\" data-label=\"Chrome\">no Chrome run yet</td>");
        const t = Tally.of(failures[si], .crane_only);
        try w.print("<td class=\"n\" data-label=\"Fail only in Crane\" data-v=\"{d}\">", .{t.total()});
        if (t.total() == 0) try w.writeAll("<span class=\"quiet\">none</span>") else {
            try w.writeAll("<a class=\"fail\" href=\"");
            try suiteHref(w, s.suite);
            try w.writeAll("\">");
            try tallyText(w, t);
            try w.writeAll("</a>");
        }
        try w.writeAll("</td></tr>\n");
    }
    try w.writeAll("</tbody>\n</table>\n");
    if (m.todomvc) |t| if (not_served > 0) {
        try w.writeAll("<p class=\"fine\">Not run, because they cannot be served: ");
        var k: u32 = 0;
        for (t.apps) |app| if (app.not_served) |why| {
            if (k > 0) try w.writeAll("; ");
            k += 1;
            try html.text(w, app.title);
            try w.writeAll(" (");
            try html.text(w, why);
            try w.writeAll(")");
        };
        try w.writeAll(".</p>\n");
    };
    try w.writeAll("</details>\n");
}

fn countKind(r: Run, kind: journal.NotRun) u32 {
    var n: u32 = 0;
    for (r.tests) |t| {
        if (t.not_run == kind) n += 1;
    }
    return n;
}

/// "(Angular 13, htmx 13, jQuery 76)" for the frameworks' own suites, A to Z.
const Named = struct { []const u8, u32 };

fn perFramework(arena: Allocator, w: W, suites: []const SuiteRuns, count: *const fn (SuiteRuns) u32) !u32 {
    var items: std.ArrayList(Named) = .empty;
    var total: u32 = 0;
    for (suites) |s| {
        if (s.suite.kind != .project) continue;
        const n = count(s);
        if (n == 0) continue;
        total += n;
        try items.append(arena, .{ s.suite.title, n });
    }
    std.mem.sort(Named, items.items, {}, struct {
        fn lt(_: void, a: Named, b: Named) bool {
            return std.ascii.lessThanIgnoreCase(a[0], b[0]);
        }
    }.lt);
    if (items.items.len == 0) return 0;
    try w.writeAll(" (");
    for (items.items, 0..) |x, i| {
        if (i > 0) try w.writeAll(", ");
        try html.text(w, x[0]);
        try w.writeByte(' ');
        try html.num(w, x[1]);
    }
    try w.writeAll(")");
    return total;
}

fn countOf(comptime kind: journal.NotRun) *const fn (SuiteRuns) u32 {
    return struct {
        fn f(s: SuiteRuns) u32 {
            const r = latest(s) orelse return 0;
            var n = countKind(r, kind);
            if (kind == .project_skip) for (r.pages) |p| {
                n += p.unnamed_pending orelse 0;
            };
            return n;
        }
    }.f;
}

fn fileCount(s: SuiteRuns) u32 {
    return @intCast(s.file_entries.len);
}

fn sumOver(suites: []const SuiteRuns, kind: journal.SuiteKind, count: *const fn (SuiteRuns) u32) u32 {
    var n: u32 = 0;
    for (suites) |s| if (s.suite.kind == kind) {
        n += count(s);
    };
    return n;
}

/// Section 4, the one place the reasons are given.
fn writeNotRun(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns, waiting: []const manifest.Framework) !void {
    try w.writeAll("<ul class=\"fw-facts\">\n");
    // Rendering.
    const rendering = sumOver(suites, .project, countOf(.rendering));
    try w.writeAll("<li><strong>Rendering.</strong> ");
    try html.text(w, rendering_statement);
    if (rendering > 0) {
        try w.writeAll(" Not run for this reason: ");
        try html.plural(w, rendering, "test", "tests");
        _ = try perFramework(arena, w, suites, countOf(.rendering));
        try w.writeAll(", each listed with its reason on its framework&#39;s page.");
    }
    try w.writeAll("</li>\n");
    // The protocols.
    if (waiting.len > 0) {
        try w.writeAll("<li><strong>Browser-automation protocols.</strong> ");
        for (waiting, 0..) |fw, i| {
            if (i > 0) try w.writeAll(if (i + 1 == waiting.len) " and " else ", ");
            try w.writeAll("<a href=\"");
            try html.href(w, fw.id);
            try w.writeAll("/\">");
            try html.text(w, fw.title);
            try w.writeAll("</a>");
        }
        try w.writeAll(" run their browser tests only through Playwright or Puppeteer, which drive the browser over the Chrome DevTools Protocol (CDP) or WebDriver BiDi. Crane does not speak either yet, so these suites wait until after Crane 0.1; Crane does not run them through a harness of its own instead. Each framework&#39;s page names its suites and their runners.</li>\n");
    }
    // Node.
    try w.writeAll("<li><strong>Node.</strong> ");
    try html.text(w, node_note);
    try w.writeAll("</li>\n");
    // What the projects leave out themselves, and the rest.
    const skipped = sumOver(suites, .project, countOf(.project_skip));
    const files = sumOver(suites, .project, fileCount);
    const app_skips = sumOver(suites, .todomvc_port, countOf(.project_skip));
    const server = sumOver(suites, .project, countOf(.needs_server));
    const node_build = sumOver(suites, .project, countOf(.needs_node_build));
    var other_suites = false;
    for (m.frameworks) |fw| for (fw.not_run) |nr| {
        other_suites = other_suites or nr.waits_for == null;
    };
    if (skipped + files + app_skips + server + node_build > 0 or other_suites) {
        try w.writeAll("<li><strong>Left out by the projects, and the rest.</strong>");
        if (skipped > 0) {
            try w.writeAll(" The projects skip ");
            try html.plural(w, skipped, "test", "tests");
            _ = try perFramework(arena, w, suites, countOf(.project_skip));
            try w.writeAll(" themselves.");
        }
        if (files > 0) {
            try w.writeAll(" ");
            try html.plural(w, files, "test file runs", "test files run");
            try w.writeAll(" only through the project&#39;s Node test runner, not in a browser page");
            _ = try perFramework(arena, w, suites, fileCount);
            try w.writeAll(".");
        }
        if (server > 0) {
            try w.writeAll(" ");
            try html.plural(w, server, "test needs", "tests need");
            try w.writeAll(" the project&#39;s own test server, which is not run");
            _ = try perFramework(arena, w, suites, countOf(.needs_server));
            try w.writeAll(".");
        }
        if (node_build > 0) {
            try w.writeAll(" ");
            try html.plural(w, node_build, "test needs", "tests need");
            try w.writeAll(" a file the project&#39;s Node build writes");
            _ = try perFramework(arena, w, suites, countOf(.needs_node_build));
            try w.writeAll(".");
        }
        if (app_skips > 0) {
            try w.writeAll(" TodoMVC&#39;s app spec skips ");
            try html.plural(w, app_skips, "test", "tests");
            try w.writeAll(" for the apps it names (its localStorage test for apps that keep nothing there, and each app&#39;s known issues).");
        }
        for (m.frameworks) |fw| for (fw.not_run) |nr| if (nr.waits_for == null) {
            try w.writeAll(" ");
            try html.text(w, fw.title);
            try w.writeAll("&#39;s ");
            try html.text(w, nr.name);
            try w.writeAll(": ");
            try html.text(w, nr.why);
        };
        try w.writeAll("</li>\n");
    }
    try w.writeAll("</ul>\n");
}

/// One suite in "How this was measured": its source, its Crane run and its
/// Chrome run, and its earlier runs.
fn suiteMethod(w: W, s: SuiteRuns) !void {
    try html.text(w, s.suite.title);
    try w.writeByte(' ');
    try html.text(w, s.suite.version);
    try w.writeAll(": <a href=\"");
    try html.text(w, s.suite.repository);
    try w.writeAll("\">");
    try html.text(w, s.suite.repository);
    try w.writeAll("</a> at ");
    try html.text(w, s.suite.tag);
    try w.writeAll(" (<code>");
    try html.text(w, s.suite.commit[0..@min(12, s.suite.commit.len)]);
    try w.writeAll("</code>), ");
    try html.text(w, s.suite.runner);
    try w.writeAll(". ");
    if (latest(s)) |r| {
        try w.writeAll("Crane: run <code>");
        try html.text(w, r.label);
        try w.writeAll("</code>, Crane <code>");
        try html.text(w, r.crane_commit);
        try w.writeAll("</code>");
        if (r.generation) |g| try w.print(" of generation {d}", .{g});
        try w.writeAll(" (console sha256 <code>");
        try html.text(w, r.console_sha256[0..@min(16, r.console_sha256.len)]);
        try w.writeAll("&hellip;</code>)");
        if (r.pages.len > 0) if (r.pages[0].server) |srv| {
            try w.writeAll("; served by the project&#39;s own test server, ");
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
        };
        try w.writeAll(". ");
    }
    if (s.chrome) |c| {
        try w.writeAll("Chrome: ");
        try html.text(w, c.browser.?);
        try w.writeAll(" (sha256 <code>");
        try html.text(w, c.console_sha256[0..@min(16, c.console_sha256.len)]);
        try w.writeAll("&hellip;</code>), ");
        if (c.pages.len > 0) if (c.pages[0].imported) |im| {
            try w.writeAll("by the project&#39;s own runner (");
            try html.text(w, im.runner);
            try w.writeAll(") on ");
            try html.text(w, im.date);
            try w.writeAll(", read from its log <code>");
            try html.text(w, im.log);
            try w.writeAll("</code>, ");
        };
        try w.writeAll("run <code>");
        try html.text(w, c.label);
        try w.writeAll("</code>. ");
    } else try w.writeAll("No Chrome run yet. ");
    if (s.runs.len > 1) {
        try w.writeAll("Earlier Crane runs, tests passed: ");
        for (s.runs[0 .. s.runs.len - 1], 0..) |r, i| {
            if (i > 0) try w.writeAll(", ");
            try w.writeAll("<code>");
            try html.text(w, r.label);
            try w.writeAll("</code> ");
            try html.num(w, r.counts.pass);
        }
        try w.writeAll(". ");
    }
    if (s.suite.note) |note| try html.text(w, note);
}

// ============================================================================
// A framework's page and an app's page
// ============================================================================

/// The figures that open a suite's page: Crane's tests passed with its
/// counts, Chrome's beside them, one meter.
fn figures(w: W, s: SuiteRuns, fs: []const Failure) !void {
    const r = latest(s) orelse {
        try w.writeAll("<p>No run yet.</p>\n");
        return;
    };
    const c = r.counts;
    try w.writeAll("<div class=\"figures\" role=\"group\" aria-label=\"Crane\">\n<p class=\"figures-main\"><span class=\"fg-pass\">");
    try html.num(w, c.pass);
    try w.writeAll("</span><span class=\"fg-of\"> / ");
    try html.num(w, c.ran());
    try w.writeAll("</span> <span class=\"fg-label\">tests passing in Crane</span></p>\n<dl class=\"figures-counts\">");
    const have_chrome = s.chrome != null;
    const only = Tally.of(fs, if (have_chrome) .crane_only else .no_chrome);
    const shared = Tally.of(fs, .shared);
    try w.print("<div{s}><dt>{s}</dt><dd>", .{ if (only.tests > 0) " class=\"fail\"" else "", if (have_chrome) "Fail only in Crane" else "Fail (no Chrome run to compare)" });
    try html.num(w, only.tests);
    try w.writeAll("</dd></div>");
    if (have_chrome) {
        try w.writeAll("<div><dt>Fail in Chrome too</dt><dd>");
        try html.num(w, shared.tests);
        try w.writeAll("</dd></div>");
    }
    if (only.pages + shared.pages > 0) {
        try w.writeAll("<div class=\"blk\"><dt>Pages that stop early</dt><dd>");
        try html.num(w, only.pages + shared.pages);
        try w.writeAll("</dd></div>");
    }
    try w.writeAll("<div><dt>Not run</dt><dd>");
    try html.num(w, c.rendering + c.not_run + @as(u32, @intCast(s.file_entries.len)));
    try w.writeAll("</dd></div><div><dt>");
    try w.writeAll(if (s.suite.kind == .todomvc_port) "Skipped by the app spec" else "Skipped by the project");
    try w.writeAll("</dt><dd>");
    try html.num(w, c.project_skip);
    try w.writeAll("</dd></div></dl>\n</div>\n");
    if (s.chrome) |ch| {
        try w.writeAll("<p class=\"figures-ref\"><span class=\"ref-name\">Chrome</span> <b>");
        try html.num(w, ch.counts.pass);
        try w.writeAll("</b> / ");
        try html.num(w, ch.counts.ran());
        try w.writeAll(" tests passing");
        if (ch.pages.len > 0 and ch.pages[0].imported != null) try w.writeAll(", by the project&#39;s own runner, which runs every test (the ones Crane does not run too)") else try w.writeAll(" on the same pages");
        try w.writeAll("</p>\n");
    } else try w.writeAll("<p class=\"figures-ref\">No Chrome run yet.</p>\n");
    try meter(w, c);
}

/// The listing of some failures: a test with its first failing assertion,
/// or a page that stopped with its message.
fn failureTable(w: W, fs: []const Failure) !void {
    try w.writeAll("<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">Test</th><th scope=\"col\">Page</th><th scope=\"col\">First failing assertion</th></tr></thead>\n<tbody>\n");
    for (fs) |f| {
        try w.writeAll("<tr><th scope=\"row\">");
        if (f.test_rec) |t| {
            try html.text(w, t.id);
            if (t.status != .FAIL) try w.print(" <span class=\"fail\">({s})</span>", .{statusText(t.status)});
            try w.writeAll("</th><td data-label=\"Page\"><code>");
            try html.text(w, t.page);
            try w.writeAll("</code></td><td class=\"msg\"><pre>");
            const msg = t.message orelse "";
            try html.text(w, msg[0..@min(msg.len, 600)]);
        } else {
            const p = f.page.?;
            try w.writeAll("The whole page stops before any test runs");
            if (f.chrome_tests > 0) {
                try w.writeAll(" <span class=\"quiet\">(Chrome runs ");
                try html.plural(w, f.chrome_tests, "test", "tests");
                try w.writeAll(" there)</span>");
            }
            try w.writeAll("</th><td data-label=\"Page\"><code>");
            try html.text(w, p.page);
            try w.print("</code></td><td class=\"msg\"><pre>{t}: ", .{p.status});
            const msg = p.message orelse "";
            try html.text(w, msg[0..@min(msg.len, 600)]);
        }
        try w.writeAll("</pre></td></tr>\n");
    }
    try w.writeAll("</tbody>\n</table>\n");
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

/// The section of a suite's Crane-only failures (or, with no Chrome run,
/// all of them), by cause: the real gaps, the Chrome-only APIs, then those
/// no cause covers.
fn failsOnlySection(arena: Allocator, w: W, n: u32, m: manifest.Manifest, s: SuiteRuns, fs: []const Failure) !void {
    const have_chrome = s.chrome != null;
    const v: Verdict = if (have_chrome) .crane_only else .no_chrome;
    try sectionHead(w, n, "fails-only", if (have_chrome) "Fails only in Crane" else "Fails in Crane");
    if (!have_chrome) try w.writeAll("<p>No Chrome run of these tests yet, so it is not known whether Chrome passes them.</p>\n");
    if (Tally.of(fs, v).total() == 0) {
        try w.writeAll(if (have_chrome) "<p>None: every test that fails in Crane fails in Chrome too.</p>\n" else "<p>None.</p>\n");
    } else {
        var group: std.ArrayList(Failure) = .empty;
        const totals = try arena.alloc(u32, m.causes.len);
        @memset(totals, 0);
        for (fs) |f| if (f.verdict == v) if (f.cause) |ci| {
            totals[ci] += 1;
        };
        const order = try causeOrder(arena, totals);
        for ([_]manifest.CauseKind{ .crane_gap, .chrome_only_api }) |kind| for (order) |ci| {
            const c = m.causes[ci];
            if (c.kind != kind) continue;
            group.clearRetainingCapacity();
            for (fs) |f| if (f.verdict == v and f.cause == ci) try group.append(arena, f);
            if (group.items.len == 0) continue;
            try w.writeAll("<h3>");
            try html.text(w, c.title);
            if (kind == .chrome_only_api) try w.writeAll("<span class=\"tag\">Chrome-only API, not a standard yet</span>");
            try w.writeAll("</h3>\n");
            try failureTable(w, group.items);
        };
        group.clearRetainingCapacity();
        for (fs) |f| if (f.verdict == v and f.cause == null) try group.append(arena, f);
        if (group.items.len > 0) {
            try w.writeAll("<h3>Not yet sorted by cause</h3>\n");
            try failureTable(w, group.items);
        }
    }
    const unnamed = chromeUnnamedFailures(s);
    if (unnamed > 0) {
        try w.writeAll("<p class=\"fine\">Chrome&#39;s own run failed ");
        try html.plural(w, unnamed, "test", "tests");
        try w.writeAll(" that its output does not name; ");
        try w.writeAll(if (unnamed == 1) "it" else "they");
        try w.writeAll(" may be among those above.</p>\n");
    }
    try w.writeAll("</section>\n");
}

/// The closed sections below a suite's Crane-only failures: those Chrome
/// shares, what is not run, its pages.
fn closedSections(arena: Allocator, w: W, n: *u32, s: SuiteRuns, fs: []const Failure) !void {
    const r = latest(s) orelse return;
    var shared: std.ArrayList(Failure) = .empty;
    for (fs) |f| if (f.verdict == .shared) try shared.append(arena, f);
    if (shared.items.len > 0) {
        n.* += 1;
        try sectionHead(w, n.*, "shared", "Fails in Chrome too");
        try w.writeAll("<details class=\"fw-more\"><summary>");
        try html.plural(w, shared.items.len, "test fails", "tests fail");
        try w.writeAll(" in Crane and in Chrome: not Crane findings</summary>\n");
        try failureTable(w, shared.items);
        try w.writeAll("</details>\n</section>\n");
    }
    const not_run = r.counts.rendering + r.counts.not_run + r.counts.project_skip;
    if (not_run + s.file_entries.len > 0) {
        n.* += 1;
        try sectionHead(w, n.*, "not-run", "Not run");
        try w.writeAll("<details class=\"fw-more\"><summary>");
        try html.plural(w, not_run, "test", "tests");
        if (s.file_entries.len > 0) {
            try w.writeAll(" and ");
            try html.plural(w, s.file_entries.len, "file", "files");
        }
        try w.writeAll(", each with its reason</summary>\n");
        if (r.counts.rendering > 0) {
            try w.writeAll("<p>");
            try html.text(w, rendering_statement);
            try w.writeAll("</p>\n");
        }
        try w.writeAll("<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">Test</th><th scope=\"col\">Page</th><th scope=\"col\">Why</th></tr></thead>\n<tbody>\n");
        for (r.tests) |t| {
            const kind = t.not_run orelse continue;
            try w.writeAll("<tr><th scope=\"row\">");
            try html.text(w, t.id);
            try w.writeAll("</th><td data-label=\"Page\"><code>");
            try html.text(w, t.page);
            try w.writeAll("</code></td><td data-label=\"Why\">");
            const why = switch (kind) {
                .project_skip => switch (s.suite.kind) {
                    .project => "the project skips it (QUnit.skip, Mocha's pending)",
                    .todomvc_port => "TodoMVC's app spec skips it for this app (spec.cy.js: its localStorage test for apps that keep nothing there; tests/knownIssues.js: the app's known issues)",
                },
                else => t.reason orelse kind.label(),
            };
            try html.text(w, why[0..@min(why.len, 600)]);
            try w.writeAll("</td></tr>\n");
        }
        for (s.file_entries) |e| {
            try w.writeAll("<tr><th scope=\"row\"><code>");
            try html.text(w, e.id);
            try w.writeAll("</code> (a whole file)</th><td data-label=\"Page\"></td><td data-label=\"Why\">");
            try html.text(w, e.why);
            try w.writeAll("</td></tr>\n");
        }
        try w.writeAll("</tbody>\n</table>\n");
        var unnamed: u32 = 0;
        for (r.pages) |p| unnamed += p.unnamed_pending orelse 0;
        if (unnamed > 0) {
            try w.writeAll("<p class=\"fine\">And ");
            try html.plural(w, unnamed, "test", "tests");
            try w.writeAll(" the project skips that its runner counts without naming.</p>\n");
        }
        try w.writeAll("</details>\n</section>\n");
    }
}

fn pagesSection(w: W, n: u32, r: Run) !void {
    try sectionHead(w, n, "pages", "Pages");
    try w.writeAll("<details class=\"fw-more\"><summary>");
    try html.plural(w, r.pages.len, "page", "pages");
    try w.writeAll(", each opened in a fresh console</summary>\n<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">Page</th><th scope=\"col\">Outcome</th><th scope=\"col\" class=\"n\">Run</th><th scope=\"col\" class=\"n\">Failed</th><th scope=\"col\" class=\"n\">Not run</th><th scope=\"col\" class=\"n\">Seconds</th></tr></thead>\n<tbody>\n");
    for (r.pages) |p| {
        var c: journal.Counts = .{};
        for (r.tests) |t| if (std.mem.eql(u8, t.page, p.page)) c.add(t);
        c.pass += p.unnamed_passed orelse 0;
        c.fail += p.unnamed_failed orelse 0;
        c.project_skip += p.unnamed_pending orelse 0;
        try w.writeAll("<tr><th scope=\"row\"><code>");
        try html.text(w, p.page);
        try w.print("</code></th><td data-label=\"Outcome\"{s}>{t}", .{ if (p.status == .OK) "" else " class=\"blk\"", p.status });
        if (p.message) |msg| {
            try w.writeAll(": ");
            try html.text(w, msg[0..@min(msg.len, 300)]);
        }
        try w.print("</td><td class=\"n\" data-label=\"Run\" data-v=\"{d}\">{d}</td><td class=\"n{s}\" data-label=\"Failed\" data-v=\"{d}\">{d}</td><td class=\"n\" data-label=\"Not run\" data-v=\"{d}\">{d}</td><td class=\"n\" data-label=\"Seconds\" data-v=\"{d}\">{d}</td></tr>\n", .{ c.ran(), c.ran(), if (c.fail + c.errored() > 0) " fail" else "", c.fail + c.errored(), c.fail + c.errored(), c.rendering + c.not_run + c.project_skip, c.rendering + c.not_run + c.project_skip, p.wall_ms / 1000, p.wall_ms / 1000 });
    }
    try w.writeAll("</tbody>\n</table>\n</details>\n</section>\n");
}

/// A framework's page (<out>/<framework>/): its own suites' figures and
/// failures, then those of its own tests that do not run; its TodoMVC app
/// is linked, never shown here.
pub fn writeFramework(arena: Allocator, w: W, m: manifest.Manifest, fw: manifest.Framework, suites: []const SuiteRuns, o: Options) !void {
    var title_buf: [160]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Crane: {s}'s own tests", .{fw.title}) catch fw.title;
    try head(w, title, "A framework's own browser tests in Crane and in Chrome: what fails only in Crane, by cause, with every message; what Chrome fails too; what is not run, and why.", o, 1);
    try w.writeAll("<header class=\"head\">\n<p class=\"back-link\"><a href=\"../\">All frameworks</a></p>\n<h1>");
    try html.text(w, fw.title);
    try w.writeAll(" <span class=\"h1-rest\">in Crane</span></h1>\n<p class=\"subtitle\">");
    try html.text(w, fw.title);
    try w.writeAll("&#39;s own browser tests, run in Crane and in Chrome.");
    for (suites) |s| if (s.suite.kind == .todomvc_port and std.mem.eql(u8, s.suite.framework, fw.id)) {
        try w.writeAll(" Its TodoMVC app is measured apart: <a href=\"../todomvc/");
        try html.href(w, s.suite.framework);
        try w.writeAll("/\">");
        try html.text(w, s.suite.title);
        try w.writeAll(" TodoMVC</a>.");
    };
    try w.writeAll("</p>\n");
    var mine: std.ArrayList(usize) = .empty;
    for (suites, 0..) |s, si| if (s.suite.kind == .project and std.mem.eql(u8, s.suite.framework, fw.id)) try mine.append(arena, si);
    if (mine.items.len == 0) {
        try w.writeAll("<p class=\"lede\"><strong>Not run yet.</strong> ");
        if (neededProtocol(fw)) |p| {
            try w.writeAll("Its browser tests run only through a runner that drives the browser over ");
            try html.text(w, p.label());
            try w.writeAll(", which Crane does not speak yet; they wait until after Crane 0.1.");
        } else try w.writeAll("None of its own browser tests can run in Crane yet; the table below says why.");
        try w.writeAll("</p>\n");
    }
    // One suite's figures open the page; several suites each get theirs.
    const one = mine.items.len == 1;
    var fails: std.ArrayList([]const Failure) = .empty;
    for (mine.items) |si| try fails.append(arena, try failuresOf(arena, m.causes, suites[si]));
    if (one) try figures(w, suites[mine.items[0]], fails.items[0]);
    try w.writeAll("</header>\n");
    var n: u32 = 0;
    for (mine.items, fails.items) |si, fs| {
        const s = suites[si];
        if (!one) {
            try w.writeAll("<h2>");
            try html.text(w, s.suite.title);
            try w.writeByte(' ');
            try html.text(w, s.suite.version);
            try w.writeAll("</h2>\n");
            try figures(w, s, fs);
        }
        n += 1;
        try failsOnlySection(arena, w, n, m, s, fs);
        try closedSections(arena, w, &n, s, fs);
    }
    if (fw.not_run.len > 0) {
        n += 1;
        try sectionHead(w, n, "not-run-suites", "Its own tests Crane does not run");
        try w.writeAll("<table class=\"listing fw-cols\">\n<thead><tr><th scope=\"col\">Tests</th><th scope=\"col\" class=\"n\">Count</th><th scope=\"col\">Why</th></tr></thead>\n<tbody>\n");
        for (fw.not_run) |nr| {
            try w.writeAll("<tr><th scope=\"row\">");
            try html.text(w, nr.name);
            try w.writeAll(" <span class=\"ver\">");
            try html.text(w, nr.runner);
            try w.writeAll(", <a href=\"");
            try html.text(w, nr.repository);
            try w.writeAll("/tree/");
            try html.text(w, nr.tag);
            try w.writeAll("\">");
            try html.text(w, nr.tag);
            try w.writeAll("</a></span></th><td class=\"n\" data-label=\"Count\"");
            if (nr.tests) |t| {
                try w.print(" data-v=\"{d}\">", .{t});
                try html.num(w, t);
            } else try w.writeAll(">not counted");
            try w.writeAll("</td><td data-label=\"Why\">");
            try html.text(w, nr.why);
            try w.writeAll("</td></tr>\n");
        }
        try w.writeAll("</tbody>\n</table>\n</section>\n");
    }
    for (mine.items) |si| {
        const r = latest(suites[si]) orelse continue;
        n += 1;
        try pagesSection(w, n, r);
    }
    if (mine.items.len > 0) {
        n += 1;
        try sectionHead(w, n, "method", "How this was measured");
        try w.writeAll("<details class=\"fw-more\"><summary>The runs, the browsers and the pins</summary>\n<ul class=\"method\">\n");
        for (mine.items) |si| {
            try w.writeAll("<li>");
            try suiteMethod(w, suites[si]);
            try w.writeAll("</li>\n");
        }
        try w.writeAll("<li>");
        try html.text(w, node_note);
        try w.writeAll("</li>\n</ul>\n</details>\n</section>\n");
    }
    try w.writeAll(page_foot);
}

/// A TodoMVC app's page (<out>/todomvc/<app>/).
pub fn writeApp(arena: Allocator, w: W, m: manifest.Manifest, s: SuiteRuns, o: Options) !void {
    var title_buf: [160]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Crane: the {s} TodoMVC app", .{s.suite.title}) catch s.suite.title;
    try head(w, title, "A TodoMVC app checked in Crane and in Chrome by Crane's port of the TodoMVC app spec: what fails only in Crane, with every message.", o, 2);
    try w.writeAll("<header class=\"head\">\n<p class=\"back-link\"><a href=\"../../#todomvc\">All frameworks</a></p>\n<h1>");
    try html.text(w, s.suite.title);
    try w.writeAll(" <span class=\"h1-rest\">TodoMVC in Crane</span></h1>\n<p class=\"subtitle\">The ");
    try html.text(w, s.suite.title);
    try w.writeAll(" app from TodoMVC");
    if (s.suite.app) |app| if (app.version) |v| {
        try w.writeAll(" (");
        try html.text(w, v);
        try w.writeAll(")");
    };
    try w.writeAll(", checked by Crane&#39;s port of TodoMVC&#39;s app spec in Crane and in Chrome.");
    if (s.suite.app) |app| if (app.skipped_by_todomvc) |why| {
        try w.writeAll(" TodoMVC&#39;s own runner skips this app (tests/excluded.js): ");
        try html.text(w, why);
        try w.writeAll(". It is run here all the same.");
    };
    try w.writeAll("</p>\n");
    const fs = try failuresOf(arena, m.causes, s);
    try figures(w, s, fs);
    try w.writeAll("</header>\n");
    var n: u32 = 1;
    try failsOnlySection(arena, w, n, m, s, fs);
    try closedSections(arena, w, &n, s, fs);
    n += 1;
    try sectionHead(w, n, "method", "How this was measured");
    try w.writeAll("<details class=\"fw-more\"><summary>The build, the runs and the port</summary>\n<ul class=\"method\">\n<li>");
    if (s.suite.app) |app| {
        try w.writeAll("The app&#39;s build: <code>examples/");
        try html.text(w, app.folder);
        try w.writeAll("</code> as committed in ");
        try html.text(w, s.suite.repository);
        try w.writeAll(" at <code>");
        try html.text(w, s.suite.commit[0..@min(12, s.suite.commit.len)]);
        try w.writeAll("</code>, unmodified; <code>examples/");
        try html.text(w, app.id);
        try w.writeAll("/</code> is pinned by its sha256 <code>");
        if (app.sha256) |h| try html.text(w, h[0..@min(16, h.len)]);
        try w.writeAll("&hellip;</code>, checked at every fetch. ");
    }
    if (latest(s)) |r| {
        try w.writeAll("Crane: run <code>");
        try html.text(w, r.label);
        try w.writeAll("</code>, Crane <code>");
        try html.text(w, r.crane_commit);
        try w.writeAll("</code> (console sha256 <code>");
        try html.text(w, r.console_sha256[0..@min(16, r.console_sha256.len)]);
        try w.writeAll("&hellip;</code>). ");
    }
    if (s.chrome) |c| {
        try w.writeAll("Chrome: ");
        try html.text(w, c.browser.?);
        try w.writeAll(" on the same page, run <code>");
        try html.text(w, c.label);
        try w.writeAll("</code>. ");
    }
    try w.writeAll("</li>\n<li>");
    try html.text(w, todomvc_port_note);
    try w.writeAll(" The port: <code>tests/frameworks/todomvc/</code> in Crane; the spec: <a href=\"");
    try html.text(w, s.suite.repository);
    try w.writeAll("/blob/");
    try html.text(w, s.suite.commit);
    try w.writeAll("/cypress/e2e/spec.cy.js\"><code>cypress/e2e/spec.cy.js</code></a>.</li>\n</ul>\n</details>\n</section>\n");
    try w.writeAll(page_foot);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// Occurrences of `needle` in `hay`.
fn occurrences(hay: []const u8, needle: []const u8) usize {
    var n: usize = 0;
    var at: usize = 0;
    while (std.mem.indexOfPos(u8, hay, at, needle)) |i| : (at = i + needle.len) n += 1;
    return n;
}

const sha: [64]u8 = @splat('a');

fn suiteOf(id: []const u8, framework: []const u8, title: []const u8, version: []const u8, kind: journal.SuiteKind, pages: []const manifest.Page) manifest.Suite {
    return .{ .id = id, .framework = framework, .title = title, .version = version, .kind = kind, .repository = "https://github.com/x/y", .tag = "v1", .commit = "8d112c71624f2e48e741d740b4531d5010f057ae", .licence = "MIT", .runner = "QUnit 2.24.2", .reader = .qunit, .source = .{ .url = "https://x", .sha256 = &sha }, .pages = pages, .excluded = "x.txt" };
}

const Fixture = struct {
    tests: std.ArrayList(journal.TestRecord) = .empty,
    pages: std.ArrayList(journal.PageRecord) = .empty,

    fn testRec(f: *Fixture, a: Allocator, label: []const u8, browser: ?[]const u8, s: manifest.Suite, page: []const u8, id: []const u8, status: journal.Status, extra: struct { not_run: ?journal.NotRun = null, message: ?[]const u8 = null, reason: ?[]const u8 = null }) !void {
        try f.tests.append(a, .{ .label = label, .crane_commit = if (browser != null) "none" else "fb2911d722a", .console_sha256 = &sha, .framework = s.framework, .version = s.version, .suite = s.id, .suite_kind = s.kind, .source_sha256 = &sha, .page = page, .module = "m", .name = id, .id = id, .status = status, .not_run = extra.not_run, .message = if (status == .FAIL) extra.message orelse "expected x" else extra.message, .reason = extra.reason, .browser = browser });
    }

    fn pageRec(f: *Fixture, a: Allocator, label: []const u8, browser: ?[]const u8, s: manifest.Suite, page: []const u8, extra: struct { status: journal.PageStatus = .OK, message: ?[]const u8 = null, unnamed_passed: ?u32 = null, unnamed_failed: ?u32 = null, reported_total: ?u32 = null, imported: ?journal.Imported = null }) !void {
        try f.pages.append(a, .{ .label = label, .crane_commit = if (browser != null) "none" else "fb2911d722a", .console_sha256 = &sha, .framework = s.framework, .version = s.version, .suite = s.id, .suite_kind = s.kind, .source_sha256 = &sha, .page = page, .url = "u", .status = extra.status, .message = extra.message, .wall_ms = 2000, .reported_total = extra.reported_total, .ran = 0, .records = 0, .unnamed_passed = extra.unnamed_passed, .unnamed_failed = extra.unnamed_failed, .exit = "exited with code 0", .browser = browser, .imported = extra.imported });
    }
};

const chrome_157 = "Chrome for Testing 157.0.8103.78";

/// A manifest and journals like the published page's, in miniature:
/// Angular (a cause by message, a Chrome-only API, a page that stops, an
/// unnamed Chrome failure), htmx (no Chrome run), jQuery (a failure Chrome
/// shares, one it does not, one no cause covers), React, Svelte and Vue
/// waiting, and three TodoMVC apps.
fn fixture(a: Allocator) !struct { m: manifest.Manifest, suites: []SuiteRuns } {
    const ng = suiteOf("angular-jasmine", "angular", "Angular", "22.2.6", .project, &.{ .{ .id = "core", .path = "?a" }, .{ .id = "zone", .path = "?b" } });
    const hx = suiteOf("htmx-mocha", "htmx", "htmx", "4.0.1", .project, &.{.{ .id = "test", .path = "test/test.html" }});
    const jq = suiteOf("jquery-qunit", "jquery", "jQuery", "4.0.0", .project, &.{ .{ .id = "css", .path = "test/?module=css" }, .{ .id = "core", .path = "test/?module=core" } });
    var react_app = suiteOf("react-todomvc", "react", "React", "ff43b02e59df", .todomvc_port, &.{.{ .id = "todomvc", .path = "p" }});
    react_app.app = .{ .id = "react", .title = "React", .folder = "react/dist", .version = "19.2.5", .sha256 = &sha };
    var gwt_app = suiteOf("gwt-todomvc", "gwt", "GWT", "ff43b02e59df", .todomvc_port, &.{.{ .id = "todomvc", .path = "p" }});
    gwt_app.app = .{ .id = "gwt", .title = "GWT", .folder = "gwt", .sha256 = &sha, .skipped_by_todomvc = "it deviates" };
    var can_app = suiteOf("canjs-todomvc", "canjs", "CanJS", "ff43b02e59df", .todomvc_port, &.{.{ .id = "todomvc", .path = "p" }});
    can_app.app = .{ .id = "canjs", .title = "CanJS", .folder = "canjs", .sha256 = &sha };
    const nr = struct {
        fn f(name: []const u8, tests: ?u32, p: ?manifest.Protocol) manifest.OwnSuiteNotRun {
            return .{ .name = name, .version = "1.0.0", .repository = "https://github.com/x/y", .tag = "v1", .runner = "Playwright", .tests = tests, .why = if (p == null) "They test an application, not the framework." else "Playwright drives Chromium through CDP.", .waits_for = p };
        }
    }.f;
    const m: manifest.Manifest = .{
        // The manifest's own order is not the page's.
        .frameworks = &.{
            .{ .id = "jquery", .title = "jQuery" },
            .{ .id = "vue", .title = "Vue", .not_run = &.{ comptime nr("e2e", 36, .cdp_or_bidi), comptime nr("e2e-browser", 84, .cdp) } },
            .{ .id = "react", .title = "React", .not_run = &.{comptime nr("Playwright e2e", 19, .cdp)} },
            .{ .id = "htmx", .title = "htmx" },
            .{ .id = "angular", .title = "Angular", .not_run = &.{comptime nr("documentation-site targets", null, null)} },
            .{ .id = "svelte", .title = "Svelte", .not_run = &.{comptime nr("samples", null, .cdp)} },
        },
        .suites = try a.dupe(manifest.Suite, &.{ jq, hx, ng, react_app, gwt_app, can_app }),
        .todomvc = .{ .repository = "https://github.com/tastejs/todomvc", .commit = "ff43b02e59dfa604386bb382034b2cd07c2bcd8a", .licence = "MIT", .runner = "QUnit 2.24.2", .reader = .qunit, .source = .{ .url = "https://x", .sha256 = &sha }, .page = "p", .excluded = "todomvc-port.txt", .apps = try a.dupe(manifest.App, &.{
            react_app.app.?, gwt_app.app.?, can_app.app.?, .{ .id = "somajs", .title = "soma.js", .folder = "somajs", .not_served = "404 on todomvc.com itself" },
        }) },
        .causes = &.{
            .{ .title = "console.timeStamp() is missing", .covers = &.{.{ .suite = "angular-jasmine", .message_contains = "timeStamp() method does not exist" }} },
            .{ .title = "View Transitions: startViewTransition() throws NotSupportedError", .covers = &.{.{ .id_contains = "view transition" }} },
            .{ .title = "No Notification API: the zone.js page stops before any test", .covers = &.{.{ .suite = "angular-jasmine", .page = "zone" }} },
            .{ .title = "navigator.modelContext (WebMCP) is missing", .kind = .chrome_only_api, .covers = &.{.{ .id_contains = "WebMCP" }} },
            .{ .title = "The GWT app never shows its heading", .covers = &.{.{ .suite = "gwt-todomvc" }} },
        },
    };
    var f: Fixture = .{};
    const cr = "crane-1";
    const ch = "chrome-1";
    const imported: journal.Imported = .{ .runner = "bazel test <target>_chromium", .log = "tmp/ng.log", .log_sha256 = &sha, .date = "2026-11-14" };
    // Angular: 3 named failures in Crane, a stopped page; Chrome's run
    // counts only, 1 unnamed failure, and the stopped page's 513 tests.
    try f.testRec(a, cr, null, ng, "core", "DI perf events should not crash", .FAIL, .{ .message = "Error: <spyOn> : timeStamp() method does not exist" });
    try f.testRec(a, cr, null, ng, "core", "router view transitions should skip initial transition", .FAIL, .{ .message = "NotSupportedError" });
    try f.testRec(a, cr, null, ng, "core", "Signal Forms WebMCP Integration should fill out", .FAIL, .{ .message = "TypeError: getTools" });
    try f.testRec(a, cr, null, ng, "core", "core scrolls", .NOTRUN, .{ .not_run = .rendering, .reason = "asserts scrollY" });
    try f.pageRec(a, cr, null, ng, "core", .{ .unnamed_passed = 100 });
    try f.pageRec(a, cr, null, ng, "zone", .{ .status = .TIMEOUT, .message = "Error: describe with no children (describe() or it()): Notification API" });
    try f.pageRec(a, ch, "Chrome for Testing headless shell 159.0.8154.2", ng, "core", .{ .unnamed_passed = 103, .unnamed_failed = 1, .reported_total = 104, .imported = imported });
    try f.pageRec(a, ch, "Chrome for Testing headless shell 159.0.8154.2", ng, "zone", .{ .unnamed_passed = 513, .reported_total = 513, .imported = imported });
    // htmx: one failure, no Chrome run.
    try f.testRec(a, cr, null, hx, "test", "swap() triggers view transition events", .FAIL, .{});
    try f.testRec(a, cr, null, hx, "test", "swap() swaps", .PASS, .{});
    try f.pageRec(a, cr, null, hx, "test", .{});
    // jQuery: fill-opacity fails only in Crane (no cause: unsorted),
    // parseXML in both; an earlier run for the history.
    try f.testRec(a, "crane-0", null, jq, "css", "css: Do not append px", .PASS, .{});
    try f.pageRec(a, "crane-0", null, jq, "css", .{});
    try f.testRec(a, cr, null, jq, "css", "css: Do not append px", .FAIL, .{ .message = "Do not append px to 'fill-opacity' Expected: 1 Result: undefined" });
    try f.testRec(a, cr, null, jq, "core", "core: jQuery.parseXML - error reporting", .FAIL, .{ .message = "reports error column Expected: \"11\" Result: \"10\"" });
    try f.testRec(a, cr, null, jq, "core", "core: basics", .PASS, .{});
    try f.pageRec(a, cr, null, jq, "css", .{});
    try f.pageRec(a, cr, null, jq, "core", .{});
    try f.testRec(a, ch, chrome_157, jq, "test", "core: jQuery.parseXML - error reporting", .FAIL, .{ .message = "reports error column" });
    try f.pageRec(a, ch, chrome_157, jq, "test", .{ .unnamed_passed = 1144, .reported_total = 1145, .imported = .{ .runner = "jquery-test-runner 0.3.0", .log = "tmp/jtr.log", .log_sha256 = &sha, .date = "2026-11-14" } });
    // TodoMVC: React passes everything in both; GWT fails 2 only in Crane
    // and 1 in both; CanJS fails 1 only in Chrome.
    for ([_]manifest.Suite{ react_app, gwt_app, can_app }) |s| for ([_][]const u8{ cr, ch }) |label| {
        const b: ?[]const u8 = if (std.mem.eql(u8, label, ch)) chrome_157 else null;
        const is_chrome = b != null;
        const gwt = std.mem.eql(u8, s.id, "gwt-todomvc");
        const can = std.mem.eql(u8, s.id, "canjs-todomvc");
        try f.testRec(a, label, b, s, "todomvc", "New Todo: should add", if (gwt and !is_chrome) .FAIL else .PASS, .{});
        try f.testRec(a, label, b, s, "todomvc", "No Todos: starts with nothing", if (gwt and !is_chrome) .FAIL else .PASS, .{});
        try f.testRec(a, label, b, s, "todomvc", "Routing: should respect the back button", if (gwt or (can and is_chrome)) .FAIL else .PASS, .{});
        try f.testRec(a, label, b, s, "todomvc", "Persistence: should persist", .NOTRUN, .{ .not_run = .project_skip });
        try f.pageRec(a, label, b, s, "todomvc", .{});
    };
    const j: journal.Journal = .{ .tests = f.tests.items, .pages = f.pages.items };
    const files = [_][]const exclusions.Entry{ &.{}, &.{.{ .id = "test/a.js", .file = true, .kind = .node_runner_only, .why = "only its Node runner loads it", .line = 1 }}, &.{}, &.{}, &.{}, &.{} };
    return .{ .m = m, .suites = try collect(a, m, &.{j}, &files) };
}

test "the overview: frameworks Crane runs first, then those not run yet, each A to Z; one verdict per framework beside Chrome" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(a, &out.writer, fx.m, fx.suites, .{});
    const h = out.written();
    // The order (main, 2026-11-14): those that run, then those that wait; A to Z.
    const ng = std.mem.indexOf(u8, h, "<tr id=\"fw-angular\">").?;
    const hx = std.mem.indexOf(u8, h, "<tr id=\"fw-htmx\">").?;
    const jq = std.mem.indexOf(u8, h, "<tr id=\"fw-jquery\">").?;
    const re = std.mem.indexOf(u8, h, "<tr id=\"fw-react\">").?;
    const sv = std.mem.indexOf(u8, h, "<tr id=\"fw-svelte\">").?;
    const vu = std.mem.indexOf(u8, h, "<tr id=\"fw-vue\">").?;
    try testing.expect(ng < hx and hx < jq and jq < re and re < sv and sv < vu);
    try testing.expectEqual(@as(usize, 1), occurrences(h, "Order: the frameworks Crane runs, then those not run yet; each group A to Z."));
    // Crane beside Chrome, sortable by share; the verdict once per row.
    try testing.expect(std.mem.indexOf(u8, h, "<td class=\"n\" data-label=\"Crane\" data-v=\"1\" data-of=\"3\"><b>1</b> / 3 <span class=\"pct\">33.3%</span></td><td class=\"n\" data-label=\"Chrome\" data-v=\"1144\" data-of=\"1145\"><b>1,144</b> / 1,145 <span class=\"pct\">99.9%</span></td><td class=\"n\" data-label=\"Fail only in Crane\" data-v=\"1\"><a class=\"fail\" href=\"jquery/#fails-only\">1 test</a></td>") != null);
    // Angular: the Chrome-only API counts as failing only in Crane on its
    // row; the stopped page too.
    try testing.expect(std.mem.indexOf(u8, h, "data-label=\"Fail only in Crane\" data-v=\"4\"><a class=\"fail\" href=\"angular/#fails-only\">3 tests and 1 page</a>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<td class=\"n quiet\" data-label=\"Chrome\">no Chrome run yet</td><td class=\"n\" data-label=\"Fail only in Crane\" data-v=\"1\"><a class=\"fail\" href=\"htmx/#fails-only\">1 test</a> <span class=\"quiet\">(no Chrome run to compare)</span>") != null);
    // A waiting framework: its count and protocol, no reason repeated.
    try testing.expect(std.mem.indexOf(u8, h, "<tr id=\"fw-vue\"><th scope=\"row\"><a href=\"vue/\">Vue</a><span class=\"ver\">1.0.0</span></th><td class=\"n\" data-label=\"Its own browser tests\" data-v=\"120\">120 tests</td><td data-label=\"Waits for\">CDP</td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<td class=\"n quiet\" data-label=\"Its own browser tests\">not counted</td>") != null);
    try testing.expectEqual(@as(usize, 0), occurrences(h, "Playwright drives Chromium through CDP."));
    // Content is HTML; site.js only sorts. No meters, no sparklines.
    try testing.expect(std.mem.indexOf(u8, h, "<script src=\"../site.js\" defer></script>") != null);
    try testing.expectEqual(@as(usize, 1), occurrences(h, "<script"));
    try testing.expectEqual(@as(usize, 0), occurrences(h, "class=\"meter\""));
    try testing.expectEqual(@as(usize, 0), occurrences(h, "class=\"spark\""));
    // The header names the runs' Crane commit and browsers.
    try testing.expect(std.mem.indexOf(u8, h, "<div><dt>Crane</dt><dd><code>fb2911d722a</code> (jQuery, htmx, Angular, TodoMVC)</dd></div>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "Chrome for Testing headless shell 159.0.8154.2 (Angular)") != null);
}

test "the overview: what fails only in Crane, once, by cause; Chrome-only APIs apart; what no cause covers named; what Chrome shares left out" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(a, &out.writer, fx.m, fx.suites, .{});
    const h = out.written();
    const gaps = std.mem.indexOf(u8, h, "<h2 id=\"gaps-h\"><span class=\"secno\">2</span>What fails in Crane and passes in Chrome").?;
    const todo = std.mem.indexOf(u8, h, "<h2 id=\"todomvc-h\"><span class=\"secno\">3</span>").?;
    const sec = h[gaps..todo];
    // The lede counts the real gaps only: 4 causes, 4 tests and 1 page.
    try testing.expect(std.mem.indexOf(u8, sec, "4 causes: 5 tests and 1 page, in 2 frameworks&#39; own tests and 1 TodoMVC app.") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "<tr><th scope=\"row\">console.timeStamp() is missing</th><td class=\"n\" data-label=\"Tests\" data-v=\"1\">1 test</td><td data-label=\"Where\"><a href=\"angular/#fails-only\">Angular 1</a></td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "<tr><th scope=\"row\">View Transitions: startViewTransition() throws NotSupportedError</th><td class=\"n\" data-label=\"Tests\" data-v=\"2\">2 tests</td><td data-label=\"Where\"><a href=\"angular/#fails-only\">Angular 1</a>, <a href=\"htmx/#fails-only\">htmx 1</a> <span class=\"quiet\">(no Chrome run to compare)</span></td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "<a href=\"angular/#fails-only\">Angular 1 page</a> <span class=\"quiet\">(Chrome runs 513 tests there)</span>") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "<a href=\"todomvc/gwt/#fails-only\">TodoMVC GWT 2</a>") != null);
    // The Chrome-only API under its own heading, after the gaps.
    const own = std.mem.indexOf(u8, sec, "<h3 id=\"chrome-only\">Chrome-only APIs (not standards yet)</h3>").?;
    try testing.expect(std.mem.indexOf(u8, sec, "navigator.modelContext (WebMCP) is missing").? > own);
    try testing.expect(std.mem.indexOf(u8, sec, "console.timeStamp() is missing").? < own);
    // No cause covers fill-opacity: named, with its message.
    try testing.expect(std.mem.indexOf(u8, sec, "<h3 id=\"unsorted\">Not yet sorted by cause</h3>") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "css: Do not append px</th>") != null);
    try testing.expect(std.mem.indexOf(u8, sec, "Do not append px to &#39;fill-opacity&#39;") != null);
    // A failure Chrome shares is not here; Chrome's unnamed failure is said.
    try testing.expect(std.mem.indexOf(u8, sec, "parseXML") == null);
    try testing.expect(std.mem.indexOf(u8, sec, "Routing: should respect the back button") == null);
    try testing.expect(std.mem.indexOf(u8, sec, "Angular: Chrome&#39;s own run failed 1 test that its output does not name; it may be among the 3 counted here.") != null);
    // Once on the page: the failure is not listed again elsewhere on it.
    try testing.expectEqual(@as(usize, 1), occurrences(h, "css: Do not append px"));
}

test "the overview: TodoMVC in a few numbers, every app closed, A to Z; the not-run reasons said once" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(a, &out.writer, fx.m, fx.suites, .{});
    const h = out.written();
    try testing.expect(std.mem.indexOf(u8, h, "<tr><th scope=\"row\">Apps that pass every test</th><td class=\"n\"><b>2</b> / 3</td><td class=\"n\"><b>1</b> / 3</td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<tr><th scope=\"row\">Tests passed</th><td class=\"n\"><b>6</b> / 9</td><td class=\"n\"><b>7</b> / 9</td></tr>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<li><b class=\"fail\">2</b> tests fail only in Crane, in 1 app: <a href=\"todomvc/gwt/#fails-only\">GWT 2</a>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<li><b>1</b> test fails only in Chrome: CanJS &ldquo;Routing: should respect the back button&rdquo;.</li>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<li><b>1</b> test fails in Chrome too, so they say nothing about Crane") != null);
    // The apps, closed, A to Z (CanJS, GWT, React), with the one not served.
    const list = std.mem.indexOf(u8, h, "<details class=\"fw-more\" id=\"apps\"><summary>All 3 apps, A to Z</summary>").?;
    const can = std.mem.indexOf(u8, h, "<tr id=\"app-canjs\">").?;
    const gwt = std.mem.indexOf(u8, h, "<tr id=\"app-gwt\">").?;
    const react = std.mem.indexOf(u8, h, "<tr id=\"app-react\">").?;
    try testing.expect(list < can and can < gwt and gwt < react);
    try testing.expect(std.mem.indexOf(u8, h, "soma.js (404 on todomvc.com itself)") != null);
    // Section 4 says each reason once, here only.
    try testing.expectEqual(@as(usize, 1), occurrences(h, "Crane draws nothing"));
    try testing.expect(std.mem.indexOf(u8, h, "Not run for this reason: 1 test (Angular 1), each listed with its reason") != null);
    try testing.expectEqual(@as(usize, 1), occurrences(h, "Crane does not speak either yet"));
    try testing.expect(std.mem.indexOf(u8, h, "<a href=\"react/\">React</a>, <a href=\"svelte/\">Svelte</a> and <a href=\"vue/\">Vue</a> run their browser tests only through Playwright or Puppeteer") != null);
    try testing.expectEqual(@as(usize, 1), occurrences(h, "Node runs only the projects&#39; own build steps"));
    try testing.expect(std.mem.indexOf(u8, h, "1 test file runs only through the project&#39;s Node test runner, not in a browser page (htmx 1).") != null);
    try testing.expect(std.mem.indexOf(u8, h, "TodoMVC&#39;s app spec skips 3 tests for the apps it names") != null);
    try testing.expect(std.mem.indexOf(u8, h, "Angular&#39;s documentation-site targets: They test an application, not the framework.") != null);
    // How it was measured: closed, with Chrome's imported runner and date.
    const method = std.mem.indexOf(u8, h, "<details class=\"fw-more\"><summary>The runs, the browsers, the pins and the method</summary>").?;
    try testing.expect(std.mem.indexOf(u8, h, "by the project&#39;s own runner (jquery-test-runner 0.3.0) on 2026-11-14, read from its log <code>tmp/jtr.log</code>").? > method);
    try testing.expect(std.mem.indexOf(u8, h, "Earlier Crane runs, tests passed: <code>crane-0</code> 1.").? > method);
}

test "a framework's page: figures, Crane-only failures by cause, then closed what Chrome shares, what is not run, pages, method" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    var out: Io.Writer.Allocating = .init(a);
    try writeFramework(a, &out.writer, fx.m, fx.m.frameworks[4], fx.suites, .{});
    const h = out.written();
    try testing.expect(std.mem.indexOf(u8, h, "href=\"../../site.css\"") != null and std.mem.indexOf(u8, h, "src=\"../../site.js\"") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<span class=\"fg-pass\">100</span><span class=\"fg-of\"> / 103</span> <span class=\"fg-label\">tests passing in Crane</span>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<div class=\"fail\"><dt>Fail only in Crane</dt><dd>3</dd></div><div><dt>Fail in Chrome too</dt><dd>0</dd></div><div class=\"blk\"><dt>Pages that stop early</dt><dd>1</dd></div>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<p class=\"figures-ref\"><span class=\"ref-name\">Chrome</span> <b>616</b> / 617 tests passing, by the project&#39;s own runner") != null);
    try testing.expectEqual(@as(usize, 1), occurrences(h, "class=\"meter\""));
    // By cause, the Chrome-only API last and tagged.
    const ts = std.mem.indexOf(u8, h, "<h3>console.timeStamp() is missing</h3>").?;
    const vt = std.mem.indexOf(u8, h, "<h3>View Transitions: startViewTransition() throws NotSupportedError</h3>").?;
    const zn = std.mem.indexOf(u8, h, "<h3>No Notification API: the zone.js page stops before any test</h3>").?;
    const mc = std.mem.indexOf(u8, h, "<h3>navigator.modelContext (WebMCP) is missing<span class=\"tag\">Chrome-only API, not a standard yet</span></h3>").?;
    try testing.expect(ts < vt and vt < zn and zn < mc);
    try testing.expect(std.mem.indexOf(u8, h, "The whole page stops before any test runs <span class=\"quiet\">(Chrome runs 513 tests there)</span></th><td data-label=\"Page\"><code>zone</code></td><td class=\"msg\"><pre>TIMEOUT: Error: describe with no children") != null);
    try testing.expect(std.mem.indexOf(u8, h, "Chrome&#39;s own run failed 1 test that its output does not name; it may be among those above.") != null);
    // Closed: what is not run (with the statement, once), the pages, the method.
    try testing.expectEqual(@as(usize, 1), occurrences(h, "Crane draws nothing"));
    try testing.expect(std.mem.indexOf(u8, h, "<details class=\"fw-more\"><summary>1 test, each with its reason</summary>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<details class=\"fw-more\"><summary>2 pages, each opened in a fresh console</summary>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<h2 id=\"not-run-suites-h\">") != null);
    try testing.expect(std.mem.indexOf(u8, h, "by the project&#39;s own runner (bazel test &lt;target&gt;_chromium) on 2026-11-14") != null);

    // jQuery: the failure Chrome shares is in its closed section only.
    out.clearRetainingCapacity();
    try writeFramework(a, &out.writer, fx.m, fx.m.frameworks[0], fx.suites, .{});
    const jq = out.written();
    const shared = std.mem.indexOf(u8, jq, "<details class=\"fw-more\"><summary>1 test fails in Crane and in Chrome: not Crane findings</summary>").?;
    try testing.expect(std.mem.indexOf(u8, jq, "core: jQuery.parseXML - error reporting").? > shared);
    try testing.expect(std.mem.indexOf(u8, jq, "<h3>Not yet sorted by cause</h3>").? < shared);

    // A waiting framework: the verdict, and its suites with why.
    out.clearRetainingCapacity();
    try writeFramework(a, &out.writer, fx.m, fx.m.frameworks[1], fx.suites, .{});
    const vue = out.written();
    try testing.expect(std.mem.indexOf(u8, vue, "<strong>Not run yet.</strong> Its browser tests run only through a runner that drives the browser over the Chrome DevTools Protocol (CDP), which Crane does not speak yet; they wait until after Crane 0.1.") != null);
    try testing.expect(std.mem.indexOf(u8, vue, "<a href=\"https://github.com/x/y/tree/v1\">v1</a>") != null);
    try testing.expect(std.mem.indexOf(u8, vue, "class=\"figures\"") == null);
}

test "an app's page: figures beside Chrome, its Crane-only failures, the app spec's skips and the port's method closed" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    var out: Io.Writer.Allocating = .init(a);
    try writeApp(a, &out.writer, fx.m, fx.suites[4], .{});
    const h = out.written();
    try testing.expect(std.mem.indexOf(u8, h, "href=\"../../../site.css\"") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<a href=\"../../#todomvc\">All frameworks</a>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "TodoMVC&#39;s own runner skips this app (tests/excluded.js): it deviates. It is run here all the same.") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<span class=\"fg-pass\">0</span><span class=\"fg-of\"> / 3</span>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<h3>The GWT app never shows its heading</h3>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<summary>1 test fails in Crane and in Chrome: not Crane findings</summary>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "TodoMVC&#39;s app spec skips it for this app") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<code>examples/gwt/</code> is pinned by its sha256 <code>aaaaaaaaaaaaaaaa&hellip;</code>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "cypress/e2e/spec.cy.js") != null);
}

test "a manifest without a frameworks list: a row per framework its project suites name" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const s = suiteOf("htmx-mocha", "htmx", "htmx", "4.0.1", .project, &.{.{ .id = "test", .path = "test/test.html" }});
    const m: manifest.Manifest = .{ .suites = &.{s} };
    const suites = try collect(a, m, &.{}, &.{});
    var out: Io.Writer.Allocating = .init(a);
    try writeIndex(a, &out.writer, m, suites, .{});
    try testing.expect(std.mem.indexOf(u8, out.written(), "<tr id=\"fw-htmx\"><th scope=\"row\"><a href=\"htmx/\">htmx</a><span class=\"ver\">4.0.1</span></th><td class=\"n\" data-label=\"Crane\">no run yet</td>") != null);
}

test "rate: one decimal, rounded, never 100% with a failure; nothing run is a dash" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try rate(&out.writer, 1778, 1790);
    try rate(&out.writer, 0, 0);
    try rate(&out.writer, 13164, 13165);
    try rate(&out.writer, 5, 5);
    try testing.expectEqualStrings("99.3%&mdash;&gt;99.9%100.0%", out.written());
}
