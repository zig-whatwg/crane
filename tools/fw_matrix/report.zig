//! `fw_matrix report`: the JS framework compatibility matrix as ONE finished
//! HTML page, from journals only (tmp/plans/framework-matrix-plan.md,
//! section 4), and its social card.
//!
//!   <out>/index.html   the page:
//!                      - the chart: each framework's own tests, and TodoMVC's
//!                        apps as one row, as a pass rate in Crane (a dot)
//!                        beside Chrome (a ring) on an axis zoomed to where the
//!                        rates are; a framework Crane cannot run yet is a
//!                        hatched row that says why
//!                      - TodoMVC: the pass rate per app (open; it closes)
//!                      - what is not run, and why (closed)
//!                      - how this was measured (closed)
//!   <out>/card.png     og:image / twitter:image (card.zig), named with a
//!                      `?v=` of its hash
//!
//! The design (lane fw1 b8; the user, 2026-11-14 4:24 PM ET: "I don't want
//! the frameworks/ pages to have individual pages they link to ... I want to
//! have sections that expand instead"; 4:25 PM ET: "we don't need all of the
//! failure details on this page, we just need to know pass rates. If a test
//! suite cannot run yet that should be noted. People that have an interest
//! in Crane will just scan this page"; 4:34 PM ET: "I prefer the One Chart
//! page. Make sure it matches our existing design for the progress and
//! performance pages"): direction A of tmp/fw-site/directions/, in the WPT
//! site's stylesheet, header, faces and tokens. No failure cause, test name
//! or message is on the page: pass rates, and why a suite does not run.
//!
//! The site's rules (tools/wpt_site/DESIGN.md): every number is in the HTML
//! (the chart's dots carry theirs beside them and in a native tooltip);
//! site.js only enhances; red is failure, grey is not run; the chart is
//! drawn by the generator as inline SVG positioned in percentages, so one
//! drawing serves every width (at phone width each row stacks: its name above
//! its line, the axis kept beneath the lines, the two rates under the line).

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const W = *Io.Writer;
const html = @import("site_html");
const journal = @import("journal.zig");
const manifest = @import("manifest.zig");
const exclusions = @import("exclusions.zig");
const card = @import("card.zig");

pub const Options = struct {
    /// Where the WPT site's site.css and site.js are, relative to <out>/
    /// ("../").
    assets: []const u8 = "../",
    /// The site's URL, ending in '/': og:url and og:image are absolute.
    site_url: []const u8 = "https://zig-whatwg.github.io/crane/",
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
    /// or a project runner's results read by `fw_matrix import`). For a
    /// TodoMVC app, Crane's port run in Chrome - the same tests through the
    /// same harness as Crane's column - when there is one (main, 2026-11-14
    /// 7:00 PM ET).
    chrome: ?Run = null,
    /// A TodoMVC app's run by TodoMVC's own runner in a browser (Cypress,
    /// `fw_matrix import --reader=cypress`): the check of the port, stated
    /// in the method, never a column.
    check: ?Run = null,
    /// The project's own run on its stand-in browser, the reference beside
    /// Crane and Chrome: React's `yarn test` on jsdom, for React's Jest suite
    /// (lane react1, the integrator 2026-11-23). A run whose browser is
    /// jsdom (`isReference`); never the Chrome column.
    reference: ?Run = null,
};

/// A run in jsdom, the stand-in browser a project's own Node test runner
/// uses (React's Jest suite): the reference column, not a browser's.
fn isReference(browser: []const u8) bool {
    return std.mem.startsWith(u8, browser, "jsdom");
}

/// How Crane's TodoMVC numbers are made (the method section).
pub const todomvc_port_note =
    "Crane runs TodoMVC's app spec (cypress/e2e/spec.cy.js, 29 tests) through Crane's port of it: the same tests, steps and checks in the app's own page, driving the unmodified app through DOM events as Cypress drives it, with Cypress's configuration read from the project's cypress.config.js (includeShadowDom: queries reach into shadow roots as Cypress's do). What the port cannot do in Crane is layout: an element counts as visible by its computed style (no box, visibility, opacity) and not by its size, clipping or transforms, and an action neither scrolls the element into view nor checks that something covers it. Cypress's hooks that run before an app's own scripts have no in-page equivalent: an app counts as started when its page has loaded and its heading is visible, and the spec's spy on localStorage.setItem is installed then.";

/// How Chrome's TodoMVC numbers are made.
pub const todomvc_chrome_note =
    "Chrome's TodoMVC numbers are the same port run in Chrome for Testing: the same tests through the same harness as Crane's, so the two columns differ only by the browser.";

/// What a test's message says when Cypress did not run it after a failed
/// hook (main.zig importCypress).
const mocha_skip_marker = "a hook failed earlier in its suite";

/// Why rendering tests are not run.
pub const rendering_statement =
    "Crane draws nothing, so tests whose result depends on layout geometry or pixels are not run. Computed style, events, timers and animations do run.";

/// Why a test whose failure golden rule 2 decides is counted in neither
/// column (AGENTS.md golden rule 2; the WPT gate's follows-majority
/// exemption, the user 2026-11-18).
/// Why a jsdom-only test counts in no column.
pub const jsdom_only_statement =
    "React's own Jest suite runs on jsdom, a stand-in browser in Node. A test that asserts something jsdom does and Chrome, Firefox and Safari all do differently (a style serialization jsdom drops, a property jsdom lacks, jsdom's own internals) fails in every real browser, so it counts in neither column.";

/// Why a needs-node test counts in no column.
pub const needs_node_statement =
    "A few of React's Jest tests use an API only Node has - AsyncLocalStorage carrying a request across an await, which no browser has yet - so they cannot pass in any browser and count in neither column.";

pub const rulings_statement =
    "Some tests fail in Crane because Crane does what the browser majority does, or what the newer spec says and a shipping browser does, where the test expects another browser's behaviour. Like rendering tests, they are counted in neither column.";

/// Where Node runs (the user, 2026-11-11 5:43 PM ET: "we can run node for
/// the purposes of these tests").
pub const node_note =
    "Node runs only the projects' own build steps, test servers and test runners, never inside Crane. jQuery's pages are served by its own test server (jquery-test-runner) with its own dependencies. Angular, htmx, React, Svelte and Vue are run by their own test runners, which drive Crane over the Chrome DevTools Protocol as they drive Chrome: Playwright through Crane's WebDriver server (htmx's web-test-runner, React's suites, Svelte's and Vue's Vitest), Puppeteer by launching Crane's console (Vue's e2e tests, Angular's Bazel web-test-runner). The TodoMVC apps are static files, served as they are.";

/// The runs in `journals` grouped by suite, each suite's runs ordered by
/// generation (lane runs, with none, after) then label.
pub fn collect(arena: Allocator, m: manifest.Manifest, journals: []const journal.Journal, file_entries: []const []const exclusions.Entry) ![]SuiteRuns {
    var out: std.ArrayList(SuiteRuns) = .empty;
    for (m.suites, 0..) |s, si| {
        var runs: std.ArrayList(Run) = .empty;
        var chrome: ?Run = null;
        var check: ?Run = null;
        var reference: ?Run = null;
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
                    // The latest by label (labels name their time). A TodoMVC
                    // app's run by its own runner is the port's check.
                    const slot = if (s.kind == .todomvc_port and first.imported != null) &check else if (isReference(run.browser.?)) &reference else &chrome;
                    if (slot.* == null or std.mem.order(u8, slot.*.?.label, label) == .lt) slot.* = run;
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
        try out.append(arena, .{ .suite = s, .runs = runs.items, .file_entries = if (si < file_entries.len) file_entries[si] else &.{}, .chrome = chrome, .check = check, .reference = reference });
    }
    return out.items;
}

fn latest(s: SuiteRuns) ?Run {
    return if (s.runs.len == 0) null else s.runs[s.runs.len - 1];
}

/// Every test of the run passed and every page ended normally.
fn allPass(r: Run) bool {
    if (r.counts.ran() == 0 or r.counts.fail > 0 or r.counts.errored() > 0) return false;
    for (r.pages) |p| if (p.status != .OK) return false;
    return true;
}

// ============================================================================
// The chart's rows
// ============================================================================

/// One row of the chart: a framework's own tests, TodoMVC's apps together,
/// or a framework Crane cannot run yet.
pub const Row = struct {
    /// Its anchor: the framework's id, or "todomvc".
    id: []const u8,
    title: []const u8,
    /// The line under the name ("22.2.6 · its own tests").
    sub: []const u8,
    /// Crane's tests, null with no run yet.
    crane: ?journal.Counts = null,
    /// Chrome's, null with no Chrome run.
    chrome: ?journal.Counts = null,
    /// The project's own run on its stand-in browser (SuiteRuns.reference:
    /// jsdom for React's Jest suite), null with none.
    reference: ?journal.Counts = null,
    /// It cannot run yet: the protocol its test runner drives the browser
    /// with, which Crane does not speak.
    waits: ?manifest.Protocol = null,
    /// Crane's tests in neither count (section 3's lists), by why: what the
    /// row says under its rates (`writeNotCounted`).
    not_counted: NotCounted = .{},
};

/// A row's tests that its latest runs did not run - listed, with their
/// reason, in section 3, and in neither count - by why.
pub const NotCounted = struct {
    n: [kind_count]u32 = @splat(0),

    const kind_count = std.meta.fieldNames(journal.NotRun).len;

    pub fn of(self: NotCounted, kind: journal.NotRun) u32 {
        return self.n[@backingInt(kind)];
    }

    pub fn total(self: NotCounted) u32 {
        var t: u32 = 0;
        for (self.n) |x| t += x;
        return t;
    }

    /// Add run `r`'s: its tests not run, and the ones its framework counted
    /// as pending without naming them (project skips, as section 3 counts).
    fn addRun(self: *NotCounted, r: Run) void {
        inline for (comptime std.meta.fieldNames(journal.NotRun)) |name| {
            const kind = @field(journal.NotRun, name);
            self.n[@backingInt(kind)] += countKind(r, kind);
        }
        for (r.pages) |p| self.n[@backingInt(journal.NotRun.project_skip)] += p.unnamed_pending orelse 0;
    }
};

/// The first section's frameworks, or (a manifest without that list) one per
/// framework a project suite names.
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

fn byTitle(_: void, a: Row, b: Row) bool {
    return std.ascii.lessThanIgnoreCase(a.title, b.title);
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

/// The chart's rows: the frameworks Crane runs, A to Z; TodoMVC; then those
/// it cannot run yet, A to Z (main's order, 2026-11-14).
pub fn chartRows(arena: Allocator, m: manifest.Manifest, suites: []const SuiteRuns) ![]const Row {
    var running: std.ArrayList(Row) = .empty;
    var waiting: std.ArrayList(Row) = .empty;
    for (try frameworkList(arena, m)) |fw| {
        var row: Row = .{ .id = fw.id, .title = fw.title, .sub = "" };
        var has_suite = false;
        for (suites) |s| {
            if (s.suite.kind != .project or !std.mem.eql(u8, s.suite.framework, fw.id)) continue;
            if (!has_suite) row.sub = try std.fmt.allocPrint(arena, "{s} \u{b7} its own tests", .{s.suite.version});
            has_suite = true;
            if (latest(s)) |r| {
                var c = row.crane orelse journal.Counts{};
                c.merge(r.counts);
                row.crane = c;
                row.not_counted.addRun(r);
            }
            if (s.chrome) |r| {
                var c = row.chrome orelse journal.Counts{};
                c.merge(r.counts);
                row.chrome = c;
            }
            if (s.reference) |r| {
                var c = row.reference orelse journal.Counts{};
                c.merge(r.counts);
                row.reference = c;
            }
        }
        if (has_suite) {
            try running.append(arena, row);
        } else if (manifest.waits(m, fw)) {
            row.waits = neededProtocol(fw);
            row.sub = if (fw.not_run.len > 0) fw.not_run[0].version else "";
            try waiting.append(arena, row);
        }
    }
    std.mem.sort(Row, running.items, {}, byTitle);
    std.mem.sort(Row, waiting.items, {}, byTitle);
    var apps: u32 = 0;
    var todo: Row = .{ .id = "todomvc", .title = "TodoMVC", .sub = "" };
    for (suites) |s| if (s.suite.kind == .todomvc_port) {
        apps += 1;
        if (latest(s)) |r| {
            var c = todo.crane orelse journal.Counts{};
            c.merge(r.counts);
            todo.crane = c;
            todo.not_counted.addRun(r);
        }
        if (s.chrome) |r| {
            var c = todo.chrome orelse journal.Counts{};
            c.merge(r.counts);
            todo.chrome = c;
        }
    };
    if (apps > 0) {
        todo.sub = try std.fmt.allocPrint(arena, "all {d} apps\u{2019} tests", .{apps});
        try running.append(arena, todo);
    }
    try running.appendSlice(arena, waiting.items);
    return running.items;
}

/// Passed over run, as a percentage.
fn pct(c: journal.Counts) ?f64 {
    if (c.ran() == 0) return null;
    return @as(f64, @floatFromInt(c.pass)) * 100.0 / @as(f64, @floatFromInt(c.ran()));
}

/// Passed over run, one decimal; never "100.0%" unless every test passed
/// (card.rateOf: the card writes every rate the same way).
fn rate(w: W, pass: u32, ran: u32) !void {
    if (ran == 0) return w.writeAll("&mdash;");
    var buf: [16]u8 = undefined;
    try html.text(w, rateText(&buf, pass, ran));
}

/// The same, as plain text (a tooltip, a description).
fn rateText(buf: []u8, pass: u32, ran: u32) []const u8 {
    const r = card.rateOf(pass, ran) orelse return "no tests";
    return r.text(buf);
}

/// "12,099 / 12,126" as plain text.
fn countsText(arena: Allocator, c: journal.Counts) ![]const u8 {
    var out: Io.Writer.Allocating = .init(arena);
    try html.num(&out.writer, c.pass);
    try out.writer.writeAll(" / ");
    try html.num(&out.writer, c.ran());
    return out.written();
}

// ============================================================================
// The scale: one linear 0-100% axis (the user, 2026-11-14 8:15 PM ET)
// ============================================================================

/// The axis's ticks, in percent.
const ticks = [_]u32{ 0, 25, 50, 75, 100 };

/// The x of a rate on the chart's one linear scale, 0% at the left edge and
/// 100% at the right, as a fraction of the plot's width (the user,
/// 2026-11-14 8:15 PM ET: "Do not compress the 99th percentile. The
/// horizontal is 0% - 100% linear.").
fn xOf(rate_pct: f64) f64 {
    return @min(1.0, @max(0.0, rate_pct / 100.0));
}

fn pctAttr(w: W, frac: f64) !void {
    try w.print("{d:.2}%", .{frac * 100});
}

// ============================================================================
// The page
// ============================================================================

pub const Output = struct {
    index_html: []const u8,
    card_png: []const u8,
};

/// The page and its card from the collected runs.
pub fn render(arena: Allocator, m: manifest.Manifest, suites: []const SuiteRuns, o: Options) !Output {
    const rows = try chartRows(arena, m, suites);
    const png = try card.render(arena, try cardFigures(arena, rows));
    const card_ref = try std.fmt.allocPrint(arena, "card.png?v={x:0>8}", .{@as(u32, @truncate(std.hash.Wyhash.hash(0, png)))});
    var out: Io.Writer.Allocating = .init(arena);
    try writeIndex(arena, &out.writer, m, suites, rows, o, card_ref);
    return .{ .index_html = out.written(), .card_png = png };
}

/// The card's rows: every row's rates in tenths of a percent.
fn cardFigures(arena: Allocator, rows: []const Row) !card.Figures {
    var out: std.ArrayList(card.Row) = .empty;
    var waiting: std.ArrayList([]const u8) = .empty;
    for (rows) |r| {
        if (r.waits != null) {
            try waiting.append(arena, r.title);
            continue;
        }
        try out.append(arena, .{ .title = r.title, .crane = if (r.crane) |c| card.rateOf(c.pass, c.ran()) else null, .chrome = if (r.chrome) |c| card.rateOf(c.pass, c.ran()) else null });
    }
    return .{ .rows = out.items, .waiting = waiting.items };
}

/// "Angular 99.8%, htmx 99.9% and jQuery 99.4% of their own tests pass in
/// Crane (Chrome: ...); TodoMVC's 43 apps 76.4% (Chrome 76.7%); React,
/// Svelte and Vue wait for CDP." - from the rows, for every description.
fn writeDescription(w: W, rows: []const Row) !void {
    var buf: [16]u8 = undefined;
    var own: usize = 0;
    for (rows) |r| {
        if (r.waits != null or std.mem.eql(u8, r.id, "todomvc")) continue;
        const c = r.crane orelse continue;
        try w.writeAll(if (own == 0) "Crane passes " else ", ");
        own += 1;
        try w.print("{s} {s}", .{ r.title, rateText(&buf, c.pass, c.ran()) });
    }
    if (own > 0) try w.writeAll(" of the frameworks' own tests");
    var chrome_n: usize = 0;
    for (rows) |r| {
        if (r.waits != null or std.mem.eql(u8, r.id, "todomvc")) continue;
        if (r.crane == null) continue;
        const c = r.chrome orelse continue;
        try w.writeAll(if (chrome_n == 0) " (Chrome: " else ", ");
        chrome_n += 1;
        try w.print("{s} {s}", .{ r.title, rateText(&buf, c.pass, c.ran()) });
    }
    if (chrome_n > 0) try w.writeAll(")");
    for (rows) |r| if (std.mem.eql(u8, r.id, "todomvc")) {
        const c = r.crane orelse break;
        try w.writeAll(if (own > 0) "; " else "Crane passes ");
        try w.print("{s} of TodoMVC's apps' tests", .{rateText(&buf, c.pass, c.ran())});
        if (r.chrome) |g| try w.print(" (Chrome {s})", .{rateText(&buf, g.pass, g.ran())});
    };
    var waiting: usize = 0;
    var total_waiting: usize = 0;
    var protocol: manifest.Protocol = .cdp;
    for (rows) |r| if (r.waits) |p| {
        total_waiting += 1;
        if (p != .cdp) protocol = p;
    };
    for (rows) |r| if (r.waits != null) {
        try w.writeAll(if (waiting == 0) "; " else if (waiting + 1 == total_waiting) " and " else ", ");
        waiting += 1;
        try w.writeAll(r.title);
        if (waiting == total_waiting) try w.print(" can't run yet: {s} for {s}", .{ if (total_waiting == 1) "it waits" else "they wait", protocol.short() });
    };
    try w.writeAll(". Crane is a headless web platform engine in Zig.");
}

fn writeHead(w: W, arena: Allocator, rows: []const Row, o: Options, card_ref: []const u8) !void {
    var d: Io.Writer.Allocating = .init(arena);
    try writeDescription(&d.writer, rows);
    const desc = d.written();
    try w.writeAll("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n<title>Crane: JavaScript frameworks</title>\n<meta name=\"description\" content=\"");
    try html.text(w, desc);
    try w.writeAll("\">\n<meta name=\"color-scheme\" content=\"light dark\">\n");
    try w.print("<link rel=\"stylesheet\" href=\"{s}site.css\">\n<link rel=\"icon\" href=\"data:,\">\n<script src=\"{s}site.js\" defer></script>\n", .{ o.assets, o.assets });
    // The social card, as the progress and performance pages give theirs.
    try w.writeAll("<link rel=\"canonical\" href=\"");
    try html.text(w, o.site_url);
    try w.writeAll("frameworks/\">\n<meta property=\"og:type\" content=\"website\">\n<meta property=\"og:site_name\" content=\"Crane\">\n<meta property=\"og:title\" content=\"Crane: JavaScript frameworks\">\n<meta property=\"og:description\" content=\"");
    try html.text(w, desc);
    try w.writeAll("\">\n<meta property=\"og:url\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("frameworks/\">\n<meta property=\"og:image\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("frameworks/");
    try html.text(w, card_ref);
    try w.writeAll("\">\n<meta property=\"og:image:type\" content=\"image/png\">\n<meta property=\"og:image:width\" content=\"1200\">\n<meta property=\"og:image:height\" content=\"630\">\n");
    try w.writeAll("<meta property=\"og:image:alt\" content=\"The share of each JavaScript framework's own tests that pass in Crane, beside Chrome, and of TodoMVC's apps' tests; the frameworks Crane cannot run yet, named.\">\n");
    try w.writeAll("<meta name=\"twitter:card\" content=\"summary_large_image\">\n<meta name=\"twitter:title\" content=\"Crane: JavaScript frameworks\">\n<meta name=\"twitter:description\" content=\"");
    try html.text(w, desc);
    try w.writeAll("\">\n<meta name=\"twitter:image\" content=\"");
    try html.text(w, o.site_url);
    try w.writeAll("frameworks/");
    try html.text(w, card_ref);
    try w.writeAll("\">\n");
    try w.writeAll(style);
    try w.writeAll("</head>\n<body>\n<div class=\"frame\">\n<main class=\"doc fw\" id=\"main\">\n");
}

const style =
    \\<style>
    \\.fw .vh { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
    \\.fw .m-fail { background: var(--fail); }
    \\.fw .key-fail { background: var(--fail); }
    \\.fw .meter.ref .m-clean, .fw .key-ref { background: var(--note-ink); }
    \\.fw .fr-bar.r .meter { height: 0.35rem; }
    \\.fw .fr-bar.r .fr-rate b { font-weight: 500; color: var(--ink-2); }
    \\.fw .ratio-good { color: var(--pass); }
    \\.fw .ratio-bad { color: var(--fail); }
    \\.fw .fig-ref { margin: 0.55rem 0 0; font: 400 0.9rem/1.4 var(--sans); color: var(--ink-2); }
    \\.fw .fig-ref b { color: var(--ink); font-weight: 600; }
    \\.fw .fw-sec { margin: 0 0 3rem; }
    \\.fw .lede { max-width: var(--measure); margin: 0 0 1rem; }
    \\.fw .fw-key { display: flex; flex-wrap: wrap; gap: 0.3rem 1.1rem; margin: 0; padding: 0; list-style: none; color: var(--ink-2); font-size: 0.8rem; }
    \\.fw .fw-key li { display: inline-flex; align-items: center; gap: 0.4rem; }
    \\.fw .fr { display: grid; grid-template-columns: minmax(8rem, 10rem) minmax(0, 1fr) 5.4rem; column-gap: 1.25rem; align-items: center; padding: 0.75rem 1rem; border-bottom: 1px solid var(--rule); }
    \\.fw .fr-head { padding-top: 0.45rem; padding-bottom: 0.45rem; background: var(--paper-2); font: 600 0.74rem/1.3 var(--sans); color: var(--ink-2); }
    \\.fw .fr-head span:last-child { grid-column: 3; text-align: right; }
    \\.fw .fr-title { display: block; font: 600 1.05rem/1.2 var(--serif); }
    \\.fw .fr-title a { color: inherit; text-decoration: none; }
    \\.fw .fr-sub { display: block; margin-top: 0.1rem; font: 400 0.78rem/1.3 var(--sans); color: var(--ink-2); }
    \\.fw .fr-bar { display: grid; grid-template-columns: 3.4rem minmax(0, 1fr) 10.6rem; column-gap: 0.75rem; align-items: center; }
    \\.fw .fr-bar + .fr-bar { margin-top: 0.35rem; }
    \\.fw .fr-who { font: 600 0.74rem/1.2 var(--sans); color: var(--ink-2); }
    \\.fw .fr .meter { margin: 0; height: 0.6rem; }
    \\.fw .fr-rate { text-align: right; white-space: nowrap; font: 400 0.8rem/1.2 var(--sans); color: var(--ink-2); font-variant-numeric: tabular-nums; }
    \\.fw .fr-rate b { margin-right: 0.4rem; font: 650 1rem/1.2 var(--sans); color: var(--ink); }
    \\.fw .fr-bar.g .fr-rate b { font-weight: 500; color: var(--ink-2); }
    \\.fw .fr-note { margin-top: 0.35rem; text-align: right; font: 400 0.76rem/1.35 var(--sans); color: var(--ink-2); }
    \\.fw .fr-note a, .fw .fr-rate a { color: inherit; text-decoration: underline; text-decoration-color: var(--rule); text-underline-offset: 0.15em; }
    \\.fw .fr-diff { text-align: right; white-space: nowrap; font: 650 0.95rem/1.2 var(--sans); font-variant-numeric: tabular-nums; }
    \\.fw .fr-diff small { display: block; margin-top: 0.1rem; font: 400 0.7rem/1.2 var(--sans); color: var(--ink-2); }
    \\.fw .fr-diff.even { color: var(--ink-2); font-weight: 500; }
    \\.fw .fr-wait { display: flex; flex-wrap: wrap; align-items: center; gap: 0.35rem 0.8rem; }
    \\.fw .fr-wait .gate { text-transform: uppercase; }
    \\.fw .fr-why { font: 400 0.86rem/1.4 var(--sans); color: var(--ink-2); }
    \\.fw .fr-axis { padding-top: 0.35rem; padding-bottom: 0.55rem; border-bottom: 0; }
    \\.fw .axis { display: block; width: 100%; height: 18px; overflow: visible; font: 400 11px var(--sans); }
    \\.fw .axis text { fill: var(--ink-2); font-variant-numeric: tabular-nums; }
    \\.fw .box-key { padding: 0.55rem 1rem; border-bottom: 1px solid var(--rule); }
    \\.fw .fw-apps .tally { justify-content: flex-end; }
    \\.fw .fw-apps .tally b { min-width: 2.9rem; text-align: right; color: var(--ink); font-weight: 600; }
    \\.fw .fw-apps td.g .tally b { color: var(--ink-2); font-weight: 500; }
    \\.fw .fw-apps tbody th { font: 400 0.95rem/1.4 var(--serif); width: auto; }
    \\.fw .fw-apps td.ratio-good, .fw .fw-apps td.ratio-bad { font-weight: 600; }
    \\.fw .fw-apps td.even { color: var(--ink-2); }
    \\.fw details.fold > summary { list-style: none; cursor: pointer; }
    \\.fw details.fold > summary::-webkit-details-marker { display: none; }
    \\.fw details.fold > summary h2 { display: inline-flex; align-items: baseline; gap: 0.6rem; }
    \\.fw details.fold > summary h2::after { content: ""; flex: none; width: 0.42rem; height: 0.42rem; border-right: 1.4px solid var(--ink-2); border-bottom: 1.4px solid var(--ink-2); transform: translateY(-0.15em) rotate(-45deg); transition: transform 180ms cubic-bezier(0.16, 1, 0.3, 1); }
    \\.fw details.fold[open] > summary h2::after { transform: translateY(-0.25em) rotate(45deg); }
    \\.fw details.fold > summary:hover h2 { color: var(--link); }
    \\.fw .fold-meta { display: block; margin: -0.3rem 0 0.4rem; font: 400 0.84rem/1.4 var(--sans); color: var(--ink-2); }
    \\.fw .facts, .fw .method { max-width: var(--measure); padding-left: 1.2rem; }
    \\.fw .facts li, .fw .method li { margin: 0 0 0.6rem; }
    \\@media (prefers-reduced-motion: reduce) { .fw details.fold > summary h2::after { transition: none; } }
    \\@media (max-width: 40rem) {
    \\  .fw .fr { grid-template-columns: minmax(0, 1fr) auto; row-gap: 0.45rem; padding: 0.7rem 0.75rem; }
    \\  .fw .fr-head { display: none; }
    \\  .fw .fr > .fr-name { grid-column: 1; grid-row: 1; }
    \\  .fw .fr > .fr-diff { grid-column: 2; grid-row: 1; }
    \\  .fw .fr-bars, .fw .fr-wait { grid-column: 1 / -1; }
    \\  .fw .fr-bar { grid-template-columns: 3.2rem minmax(0, 1fr) 4.6rem; }
    \\  .fw .fw-apps .mini { display: flex; width: 3.5rem; }
    \\  .fw .fw-apps tbody td.app-diff { text-align: right; }
    \\  .fw .fr-rate .fr-n { display: none; }
    \\  .fw .fr-axis > div:first-child, .fw .fr-axis > div:last-child { display: none; }
    \\  .fw .fr-axis > .fr-bars { grid-column: 1 / -1; }
    \\  .fw .axis .q { display: none; }
    \\}
    \\</style>
    \\
;

const page_foot = "<footer class=\"foot\"><p>Written as HTML by <code>tools/fw_matrix</code> from its journals (<code>crane-fw/1</code>); <code>site.js</code> sorts the tables.</p></footer>\n</main>\n";

/// A pass rate as the progress page draws one: a meter, green for the tests
/// that passed and red for those that failed, its length the share of the
/// tests run on one linear 0-100% scale (`xOf`).
fn meter(w: W, class: []const u8, c: journal.Counts, title: []const u8) !void {
    const ran = c.ran();
    const pass_pct = if (ran == 0) 0 else @as(f64, @floatFromInt(c.pass)) * 100.0 / @as(f64, @floatFromInt(ran));
    try w.print("<span class=\"{s}\" title=\"", .{class});
    try html.text(w, title);
    try w.writeAll("\"><span class=\"m-clean\" style=\"width:");
    try pctAttr(w, xOf(pass_pct));
    try w.writeAll("\"></span><span class=\"m-fail\" style=\"width:");
    try pctAttr(w, if (ran == 0) 0 else 1 - xOf(pass_pct));
    try w.writeAll("\"></span></span>");
}

/// Crane's pass rate less Chrome's, in points of a percent, coloured as the
/// performance page colours its ratios (green where Crane is ahead, red
/// where it is behind); "even" within a twentieth of a point.
fn diffCell(w: W, crane: ?journal.Counts, chrome: ?journal.Counts, tag: []const u8, decimals: bool) !void {
    const base = if (decimals) "fr-diff" else "n app-diff";
    const cv = if (crane) |c| pct(c) else null;
    const gv = if (chrome) |c| pct(c) else null;
    if (cv == null or gv == null) return w.print("<{s} class=\"{s} even\">&mdash;</{s}>", .{ tag, base, tag });
    const d = cv.? - gv.?;
    const shown = if (decimals) @round(d * 10) / 10 else @round(d);
    if (shown == 0) return w.print("<{s} class=\"{s} even\" data-v=\"0\">even</{s}>", .{ tag, base, tag });
    const sign = if (shown > 0) "+" else "&minus;";
    try w.print("<{s} class=\"{s} {s}\" data-v=\"{d:.2}\">{s}", .{ tag, base, if (shown > 0) "ratio-good" else "ratio-bad", d, sign });
    if (decimals) try w.print("{d:.1}", .{@abs(shown)}) else try w.print("{d}", .{@as(i64, @intFromFloat(@abs(shown)))});
    try w.print("</{s}>", .{tag});
}

fn writeRates(arena: Allocator, w: W, rows: []const Row) !void {
    try w.writeAll("<section class=\"fw-sec\" id=\"rates\" aria-labelledby=\"rates-h\">\n<h2 id=\"rates-h\"><span class=\"secno\">1</span>Pass rate per framework<a class=\"self\" href=\"#rates\" aria-label=\"Link to section 1\">&para;</a></h2>\n");
    try w.writeAll("<p class=\"lede\">Each framework&#39;s own browser tests in Crane, and the same tests in Chrome by the project&#39;s own runner; TodoMVC&#39;s apps are one row. Every bar is drawn on the same scale, from 0% to 100% of the tests run.</p>\n");
    try w.writeAll("<div class=\"box\">\n<div class=\"box-head\"><h3 class=\"box-title\">Pass rate</h3><span class=\"box-sub\">tests passed of tests run</span></div>\n");
    var any_reference = false;
    for (rows) |r| any_reference = any_reference or r.reference != null;
    try w.writeAll("<div class=\"box-key\"><ul class=\"fw-key\"><li><span class=\"key key-pass\"></span>Passed</li><li><span class=\"key key-fail\"></span>Failed</li>");
    // jsdom's own meter: a hue of its own, never the grey of "can't run".
    if (any_reference) try w.writeAll("<li><span class=\"key key-ref\"></span>jsdom, React&#39;s CI</li>");
    try w.writeAll("<li><span class=\"gate g-block\">CAN&#39;T RUN YET</span>Not run</li><li><span class=\"ratio-good\">+</span>/<span class=\"ratio-bad\">&minus;</span> Crane ahead of / behind Chrome, in points</li></ul></div>\n");
    try w.writeAll("<div class=\"fr fr-head\" aria-hidden=\"true\"><span>Framework</span><span></span><span>Crane &minus; Chrome</span></div>\n");
    var buf: [16]u8 = undefined;
    for (rows) |r| {
        try w.writeAll("<div class=\"fr\" id=\"r-");
        try html.text(w, r.id);
        try w.writeAll("\"><div class=\"fr-name\"><span class=\"fr-title\">");
        if (std.mem.eql(u8, r.id, "todomvc")) try w.writeAll("<a href=\"#todomvc\">");
        try html.text(w, r.title);
        if (std.mem.eql(u8, r.id, "todomvc")) try w.writeAll("</a>");
        try w.writeAll("</span><span class=\"fr-sub\">");
        try html.text(w, r.sub);
        try w.writeAll("</span></div>");
        if (r.waits) |p| {
            try w.print("<div class=\"fr-wait\"><span class=\"gate g-block\">Can&#39;t run yet &middot; waits for {s}</span><span class=\"fr-why\">its test runner drives the browser over {s}, which Crane does not support yet (after 0.1)</span></div><div class=\"fr-diff even\">&mdash;</div></div>\n", .{ p.short(), p.short() });
            continue;
        }
        try w.writeAll("<div class=\"fr-bars\">");
        // Crane, Chrome, and the project's own stand-in browser where it has one (jsdom: a thin meter).
        const columns = [_]?journal.Counts{ r.crane, r.chrome, r.reference };
        for (columns[0..if (r.reference != null) 3 else 2], 0..) |maybe, i| {
            const name = switch (i) {
                0 => "Crane",
                1 => "Chrome",
                else => "jsdom",
            };
            try w.print("<div class=\"fr-bar{s}\"><span class=\"fr-who\">{s}</span>", .{ switch (i) {
                0 => "",
                1 => " g",
                else => " r",
            }, name });
            if (maybe) |c| if (c.ran() > 0) {
                const title = try std.fmt.allocPrint(arena, "{s}: {s} passed ({s})", .{ name, try countsText(arena, c), rateText(&buf, c.pass, c.ran()) });
                try meter(w, if (i == 2) "meter ref" else "meter", c, title);
                try w.writeAll("<span class=\"fr-rate\"><b>");
                try rate(w, c.pass, c.ran());
                try w.writeAll("</b><span class=\"fr-n\">");
                try html.num(w, c.pass);
                try w.writeAll(" / ");
                try html.num(w, c.ran());
                try w.writeAll("</span></span></div>");
                continue;
            };
            try w.print("<span class=\"meter\"></span><span class=\"fr-rate\">{s}</span></div>", .{noRate(maybe, i == 0)});
        }
        try writeNotCounted(w, r.not_counted, std.mem.eql(u8, r.id, "todomvc"));
        try w.writeAll("</div>");
        try diffCell(w, r.crane, r.chrome, "div", true);
        try w.writeAll("</div>\n");
    }
    // The scale under the bars: 0, 25, 50, 75 and 100%.
    try w.writeAll("<div class=\"fr fr-axis\" aria-hidden=\"true\"><div></div><div class=\"fr-bars\"><div class=\"fr-bar\"><span></span><svg class=\"axis\">");
    for (ticks, 0..) |t, k| {
        const anchor = if (k == 0) "start" else if (k + 1 == ticks.len) "end" else "middle";
        // At phone width the quarter labels give way; the scale stays linear.
        try w.writeAll(if (t == 25 or t == 75) "<text class=\"q\" x=\"" else "<text x=\"");
        try pctAttr(w, xOf(@floatFromInt(t)));
        try w.print("\" y=\"14\" text-anchor=\"{s}\">{d}%</text>", .{ anchor, t });
    }
    try w.writeAll("</svg><span></span></div></div><div></div></div>\n</div>\n</section>\n");
}

/// The TodoMVC apps as the progress page lists directories: a table site.js
/// sorts, each app's rate in Crane and in Chrome with a mini meter, then the
/// difference; highest in Crane first.
fn writeTodoMvc(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns) !void {
    const App = struct { title: []const u8, crane: ?journal.Counts, chrome: ?journal.Counts, crane_all: bool, chrome_all: bool };
    var apps: std.ArrayList(App) = .empty;
    var crane_all: u32 = 0;
    var chrome_all: u32 = 0;
    var tests_each: ?u32 = null;
    var crane_total: journal.Counts = .{};
    var chrome_total: journal.Counts = .{};
    var any_chrome = false;
    for (suites) |s| if (s.suite.kind == .todomvc_port) {
        const r = latest(s);
        const a: App = .{ .title = s.suite.title, .crane = if (r) |x| x.counts else null, .chrome = if (s.chrome) |x| x.counts else null, .crane_all = if (r) |x| allPass(x) else false, .chrome_all = if (s.chrome) |x| allPass(x) else false };
        crane_all += @intFromBool(a.crane_all);
        chrome_all += @intFromBool(a.chrome_all);
        if (r) |x| {
            crane_total.merge(x.counts);
            if (x.tests.len > 0) tests_each = @intCast(x.tests.len);
        }
        if (s.chrome) |x| {
            chrome_total.merge(x.counts);
            any_chrome = true;
        }
        try apps.append(arena, a);
    };
    if (apps.items.len == 0) return;
    const key = struct {
        fn of(c: ?journal.Counts) f64 {
            const x = c orelse return -1;
            return pct(x) orelse -1;
        }
        fn lt(_: void, a: App, b: App) bool {
            const ca = of(a.crane);
            const cb = of(b.crane);
            if (ca != cb) return ca > cb;
            const ga = of(a.chrome);
            const gb = of(b.chrome);
            if (ga != gb) return ga > gb;
            return std.ascii.lessThanIgnoreCase(a.title, b.title);
        }
    };
    std.mem.sort(App, apps.items, {}, key.lt);

    try w.writeAll("<section class=\"fw-sec\" id=\"todomvc\" aria-labelledby=\"todomvc-h\">\n<h2 id=\"todomvc-h\"><span class=\"secno\">2</span>TodoMVC apps<a class=\"self\" href=\"#todomvc\" aria-label=\"Link to section 2\">&para;</a></h2>\n");
    try w.writeAll("<div class=\"figures\"><p class=\"figures-main\"><span class=\"fg-pass\">");
    try html.num(w, crane_total.pass);
    try w.writeAll("</span><span class=\"fg-of\">/ ");
    try html.num(w, crane_total.ran());
    try w.writeAll("</span><span class=\"fg-label\">TodoMVC tests passing</span></p>\n<dl class=\"figures-counts\">");
    try w.print("<div class=\"{s}\"><dt>Failed</dt><dd>", .{if (crane_total.fail > 0) "fail" else ""});
    try html.num(w, crane_total.fail);
    try w.print("</dd></div><div><dt>Apps passing every test</dt><dd>{d} of {d}</dd></div>", .{ crane_all, apps.items.len });
    if (tests_each) |n| try w.print("<div><dt>Tests per app</dt><dd>{d}</dd></div>", .{n});
    try w.writeAll("</dl>\n");
    if (any_chrome) {
        try w.writeAll("<p class=\"fig-ref\">Chrome <b>");
        try html.num(w, chrome_total.pass);
        try w.writeAll("</b> / ");
        try html.num(w, chrome_total.ran());
        try w.print(" passing, {d} of {d} apps passing every test: the same tests through the same port.</p>\n", .{ chrome_all, apps.items.len });
    }
    try w.writeAll("</div>\n<p class=\"lede\">The apps todomvc.com lists, each its framework&#39;s unmodified build, checked in both browsers by Crane&#39;s port of TodoMVC&#39;s own app spec.</p>\n");
    try w.print("<div class=\"box\">\n<div class=\"box-head\"><h3 class=\"box-title\">Apps</h3><span class=\"box-sub\">{d} apps &middot; highest in Crane first</span></div>\n", .{apps.items.len});
    try w.writeAll("<table class=\"listing listing-compare fw-apps\">\n<thead><tr><th scope=\"col\">App</th><th scope=\"col\" class=\"n\">Crane</th><th scope=\"col\" class=\"n\">Chrome</th><th scope=\"col\" class=\"n\">Crane &minus; Chrome</th></tr></thead>\n<tbody>\n");
    var buf: [16]u8 = undefined;
    for (apps.items) |a| {
        try w.writeAll("<tr><th scope=\"row\">");
        try html.text(w, a.title);
        try w.writeAll("</th>");
        for ([_]?journal.Counts{ a.crane, a.chrome }, 0..) |maybe, i| {
            const name = if (i == 0) "Crane" else "Chrome";
            const cls = if (i == 0) "n" else "n g";
            if (maybe) |c| if (c.ran() > 0) {
                try w.print("<td class=\"{s}\" data-v=\"{d}\" data-of=\"{d}\"><span class=\"tally\">", .{ cls, c.pass, c.ran() });
                try meter(w, "mini", c, try std.fmt.allocPrint(arena, "{s}, {s}: {s} passed ({s})", .{ a.title, name, try countsText(arena, c), rateText(&buf, c.pass, c.ran()) }));
                try w.print("<span class=\"vh\">{s}: </span><b>", .{name});
                try appRate(w, c.pass, c.ran());
                try w.writeAll("</b><span class=\"vh\"> (");
                try html.text(w, try countsText(arena, c));
                try w.writeAll(")</span></span></td>");
                continue;
            };
            try w.print("<td class=\"{s}\"><span class=\"vh\">{s}: </span>&mdash;</td>", .{ cls, name });
        }
        try diffCell(w, a.crane, a.chrome, "td", false);
        try w.writeAll("</tr>\n");
    }
    try w.writeAll("</tbody>\n</table>\n");
    var not_served: u32 = 0;
    if (m.todomvc) |t| for (t.apps) |app| {
        not_served += @intFromBool(app.not_served != null);
    };
    if (not_served > 0) {
        try w.writeAll("<p class=\"more-files\">");
        if (m.todomvc) |t| {
            var k: u32 = 0;
            for (t.apps) |app| if (app.not_served != null) {
                if (k > 0) try w.writeAll(if (k + 1 == not_served) " and " else ", ");
                k += 1;
                try html.text(w, app.title);
            };
        }
        try w.writeAll(if (not_served == 1) " is" else " are");
        try w.writeAll(" listed on todomvc.com but cannot be served: the site&#39;s own link answers 404 and the repository has no such app.</p>\n");
    }
    try w.writeAll("</div>\n</section>\n");
}

/// A whole percent where the rate is one ("100%", "93%"), else one decimal;
/// never 100% with a failure, never 0% with a pass.
fn appRate(w: W, pass: u32, ran: u32) !void {
    const whole = (@as(u64, pass) * 100 + ran / 2) / ran;
    if (pass < ran and whole == 100) return w.writeAll("&gt;99%");
    if (pass > 0 and whole == 0) return w.writeAll("&lt;1%");
    try w.print("{d}%", .{whole});
}

/// A rate cell with no rate: no run (Crane's "yet"), or a run that counts
/// nothing - every test it has is on section 3's lists - linked there.
fn noRate(counts: ?journal.Counts, crane: bool) []const u8 {
    if (counts) |c| if (c.errored() == 0 and c.rendering + c.not_run + c.project_skip > 0) return "<a href=\"#not-run\">none counted</a>";
    return if (crane) "no run yet" else "no run";
}

/// Under a row's rates: how many of its tests are in neither count, and why,
/// linked to section 3 - "8 not run: need a renderer", or by why when there
/// is more than one reason ("21 not run: 15 need a renderer, 6 follow a
/// ruling"). A rate that leaves tests out says so on its own row. Nothing
/// when every test counts.
fn writeNotCounted(w: W, nc: NotCounted, todomvc: bool) !void {
    const total = nc.total();
    if (total == 0) return;
    const Part = struct { n: u32, one: []const u8, many: []const u8 };
    const skipped = if (todomvc) "skipped by the apps' spec" else "skipped by the project";
    const parts = [_]Part{
        .{ .n = nc.of(.rendering), .one = "needs a renderer", .many = "need a renderer" },
        .{ .n = nc.of(.follows_majority) + nc.of(.follows_spec), .one = "follows a ruling", .many = "follow a ruling" },
        .{ .n = nc.of(.jsdom_only), .one = "asserts jsdom's behaviour", .many = "assert jsdom's behaviour" },
        .{ .n = nc.of(.needs_node), .one = "needs a Node API", .many = "need a Node API" },
        .{ .n = nc.of(.project_skip), .one = skipped, .many = skipped },
        .{ .n = nc.of(.needs_server), .one = "needs the project's test server", .many = "need the project's test server" },
        .{ .n = nc.of(.needs_node_build), .one = "needs the project's Node build", .many = "need the project's Node build" },
        .{ .n = nc.of(.node_runner_only), .one = "runs only through the project's Node runner", .many = "run only through the project's Node runner" },
    };
    var reasons: u32 = 0;
    for (parts) |p| reasons += @intFromBool(p.n > 0);
    try w.writeAll("<div class=\"fr-note\"><a href=\"#not-run\">");
    try html.num(w, total);
    try w.writeAll(" not run: ");
    var k: u32 = 0;
    for (parts) |p| if (p.n > 0) {
        if (k > 0) try w.writeAll(", ");
        k += 1;
        if (reasons > 1) {
            try html.num(w, p.n);
            try w.writeByte(' ');
        }
        try html.text(w, if (p.n == 1) p.one else p.many);
    };
    try w.writeAll("</a></div>");
}

fn countKind(r: Run, kind: journal.NotRun) u32 {
    var n: u32 = 0;
    for (r.tests) |t| {
        if (t.not_run == kind) n += 1;
    }
    return n;
}

const Named = struct { []const u8, u32 };

/// "(Angular 13, htmx 13, jQuery 76)" for the frameworks' own suites, A to Z.
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

/// "What is not run, and why": closed; its summary carries the counts.
fn writeNotRun(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns, rows: []const Row) !void {
    const rendering = sumOver(suites, .project, countOf(.rendering));
    const skipped = sumOver(suites, .project, countOf(.project_skip));
    const app_skips = sumOver(suites, .todomvc_port, countOf(.project_skip));
    const majority = sumOver(suites, .project, countOf(.follows_majority));
    const newer_spec = sumOver(suites, .project, countOf(.follows_spec));
    const jsdom_only = sumOver(suites, .project, countOf(.jsdom_only));
    const needs_node = sumOver(suites, .project, countOf(.needs_node));
    try w.writeAll("<details class=\"fold fw-sec\" id=\"not-run\">\n<summary><h2><span class=\"secno\">3</span>What is not run, and why</h2><span class=\"fold-meta\">");
    var parts: u32 = 0;
    for ([_]struct { u32, []const u8 }{ .{ rendering, "rendering" }, .{ majority + newer_spec, "following a ruling" }, .{ jsdom_only, "asserting jsdom&#39;s behaviour" }, .{ needs_node, "needing a Node API" }, .{ skipped, "skipped by the projects" }, .{ app_skips, "skipped by TodoMVC&#39;s spec" } }) |p| if (p[0] > 0) {
        if (parts > 0) try w.writeAll(" &middot; ");
        parts += 1;
        try w.print("{s} ", .{p[1]});
        try html.plural(w, p[0], "test", "tests");
    };
    try w.writeAll("</span></summary>\n<div class=\"fold-body\">\n<ul class=\"facts\">\n");
    // Rendering.
    try w.writeAll("<li><strong>Rendering.</strong> ");
    try html.text(w, rendering_statement);
    if (rendering > 0) {
        try w.writeAll(" Not run for this reason: ");
        try html.plural(w, rendering, "test", "tests");
        _ = try perFramework(arena, w, suites, countOf(.rendering));
        try w.writeAll(", each listed with its reason in the project&#39;s exclusion list (<code>tools/fw_matrix/excluded/</code>).");
    }
    try w.writeAll("</li>\n");
    // A test whose failure is the result golden rule 2 picks.
    if (majority + newer_spec > 0) {
        try w.writeAll("<li><strong>Crane follows the browsers or the newer spec.</strong> ");
        try html.text(w, rulings_statement);
        if (majority > 0) {
            try w.writeAll(" The browser majority, by a recorded ruling: ");
            try html.plural(w, majority, "test", "tests");
            _ = try perFramework(arena, w, suites, countOf(.follows_majority));
            try w.writeAll(".");
        }
        if (newer_spec > 0) {
            try w.writeAll(" The spec, which a shipping browser follows: ");
            try html.plural(w, newer_spec, "test", "tests");
            _ = try perFramework(arena, w, suites, countOf(.follows_spec));
            try w.writeAll(".");
        }
        try w.writeAll(" Each is listed with its evidence in the project&#39;s exclusion list (<code>tools/fw_matrix/excluded/</code>).</li>\n");
    }
    // A test of a jsdom-run suite that asserts what jsdom does and no browser does.
    if (jsdom_only > 0) {
        try w.writeAll("<li><strong>jsdom&#39;s behaviour.</strong> ");
        try html.text(w, jsdom_only_statement);
        try w.writeAll(" Not counted for this reason: ");
        try html.plural(w, jsdom_only, "test", "tests");
        _ = try perFramework(arena, w, suites, countOf(.jsdom_only));
        try w.writeAll(", each listed with what Chrome, Firefox and Safari do in the project&#39;s exclusion list (<code>tools/fw_matrix/excluded/</code>).</li>\n");
    }
    // A test of a jsdom-run suite that needs Node itself.
    if (needs_node > 0) {
        try w.writeAll("<li><strong>Node APIs.</strong> ");
        try html.text(w, needs_node_statement);
        try w.writeAll(" Not counted for this reason: ");
        try html.plural(w, needs_node, "test", "tests");
        _ = try perFramework(arena, w, suites, countOf(.needs_node));
        try w.writeAll(", each listed with the API in the project&#39;s exclusion list (<code>tools/fw_matrix/excluded/</code>).</li>\n");
    }
    // The frameworks that wait, and their suites.
    var waiting: u32 = 0;
    for (rows) |r| waiting += @intFromBool(r.waits != null);
    if (waiting > 0) {
        try w.writeAll("<li><strong>Browser-automation protocols.</strong> ");
        var k: u32 = 0;
        for (rows) |r| if (r.waits != null) {
            if (k > 0) try w.writeAll(if (k + 1 == waiting) " and " else ", ");
            k += 1;
            try html.text(w, r.title);
        };
        try w.writeAll(" run their browser tests only through Playwright or Puppeteer, which drive the browser over the Chrome DevTools Protocol (CDP) or WebDriver BiDi. Crane does not speak either yet, so these suites wait until after Crane 0.1; Crane does not run them through a harness of its own instead.");
        for (try frameworkList(arena, m)) |fw| for (fw.not_run) |nr| if (nr.waits_for != null) {
            try w.writeAll(" ");
            try html.text(w, fw.title);
            try w.writeAll(" ");
            try html.text(w, nr.version);
            try w.writeAll(", ");
            try html.text(w, nr.name);
            if (nr.tests) |t| {
                try w.writeAll(" (");
                try html.plural(w, t, "test", "tests");
                try w.writeAll(")");
            }
            try w.writeAll(": ");
            try html.text(w, nr.why);
        };
        try w.writeAll("</li>\n");
    }
    // Node.
    try w.writeAll("<li><strong>Node.</strong> ");
    try html.text(w, node_note);
    try w.writeAll("</li>\n");
    // What the projects leave out themselves, and the rest.
    const files = sumOver(suites, .project, fileCount);
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
    try w.writeAll("</ul>\n</div>\n</details>\n");
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
        try w.writeAll(", pinned by sha256 <code>");
        try html.text(w, c.console_sha256[0..@min(16, c.console_sha256.len)]);
        try w.writeAll("&hellip;</code>; ");
        if (c.pages.len > 0) if (c.pages[0].imported) |im| {
            try w.writeAll("the project&#39;s own runner on ");
            try html.text(w, im.date);
            try w.writeAll(": ");
            try html.text(w, im.runner);
            try w.writeAll("; read from its log <code>");
            try html.text(w, im.log);
            try w.writeAll("</code>; ");
        };
        try w.writeAll("run <code>");
        try html.text(w, c.label);
        try w.writeAll("</code>. ");
    } else try w.writeAll("No Chrome run yet. ");
    if (s.reference) |c| {
        try w.writeAll("jsdom: ");
        try html.text(w, c.browser.?);
        try w.writeAll(", pinned by sha256 <code>");
        try html.text(w, c.console_sha256[0..@min(16, c.console_sha256.len)]);
        try w.writeAll("&hellip;</code>; run <code>");
        try html.text(w, c.label);
        try w.writeAll("</code>. ");
    }
    if (s.suite.note) |note| try html.text(w, note);
}

/// "How this was measured": closed.
fn writeMethod(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns) !void {
    try w.writeAll("<details class=\"fold fw-sec\" id=\"method\">\n<summary><h2><span class=\"secno\">4</span>How this was measured</h2></summary>\n<div class=\"fold-body\">\n<ul class=\"method\">\n");
    try w.writeAll("<li>Each page is opened in Crane&#39;s console as a user opens it, and read from the test framework&#39;s own report; Chrome&#39;s numbers come from the same pages, or from the project&#39;s own runner where the project runs its tests that way. Pass rate is the tests that passed of the tests run: tests not run (below) are in neither number.</li>\n");
    var order: std.ArrayList(SuiteRuns) = .empty;
    for (suites) |s| if (s.suite.kind == .project) try order.append(arena, s);
    std.mem.sort(SuiteRuns, order.items, {}, struct {
        fn lt(_: void, a: SuiteRuns, b: SuiteRuns) bool {
            return std.ascii.lessThanIgnoreCase(a.suite.title, b.suite.title);
        }
    }.lt);
    for (order.items) |s| {
        try w.writeAll("<li>");
        try suiteMethod(w, s);
        try w.writeAll("</li>\n");
    }
    if (m.todomvc) |t| {
        try w.writeAll("<li>TodoMVC: the apps todomvc.com lists, each the unmodified build committed in <a href=\"");
        try html.text(w, t.repository);
        try w.writeAll("\">tastejs/todomvc</a> at <code>");
        try html.text(w, t.commit[0..@min(12, t.commit.len)]);
        try w.writeAll("</code>, <code>examples/&lt;app&gt;/</code> pinned by its sha256 and checked at every fetch. ");
        try html.text(w, todomvc_port_note);
        try w.writeAll(" ");
        try html.text(w, todomvc_chrome_note);
        // The apps given to Cypress, and so to the port, by their folder.
        var by_folder: u32 = 0;
        for (t.apps) |app| by_folder += @intFromBool(app.cypress_framework != null);
        if (by_folder > 0) {
            try w.writeAll(" ");
            try html.plural(w, by_folder, "app is", "apps are");
            try w.writeAll(" given to both as the folder of the build todomvc.com links (");
            var k: u32 = 0;
            for (t.apps) |app| if (app.cypress_framework) |f| {
                if (k > 0) try w.writeAll(", ");
                k += 1;
                try w.writeAll("<code>");
                try html.text(w, f);
                try w.writeAll("</code>");
            };
            try w.writeAll("), the path form of the spec&#39;s framework value: its default folders for those names are unbuilt sources. Their name-keyed settings in the spec (known issues, localStorage checks) then do not apply, in Cypress as in the port.");
        }
        // The runs.
        var crane_label: ?[]const u8 = null;
        var crane_commit: ?[]const u8 = null;
        var chrome: ?Run = null;
        for (suites) |s| if (s.suite.kind == .todomvc_port) {
            if (latest(s)) |r| {
                crane_label = r.label;
                crane_commit = r.crane_commit;
            }
            if (s.chrome) |c| chrome = c;
        };
        if (crane_label) |l| {
            try w.writeAll(" Crane: run <code>");
            try html.text(w, l);
            try w.writeAll("</code>, Crane <code>");
            try html.text(w, crane_commit.?);
            try w.writeAll("</code>.");
        }
        if (chrome) |c| {
            try w.writeAll(" Chrome: ");
            try html.text(w, c.browser.?);
            try w.writeAll(", run <code>");
            try html.text(w, c.label);
            try w.writeAll("</code>.");
        }
        try writeCheck(arena, w, suites);
        try w.writeAll("</li>\n");
    }
    try w.writeAll("</ul>\n</div>\n</details>\n");
}

/// The port checked against TodoMVC's own runner in Chrome (the apps'
/// `check` runs beside their `chrome` runs): how many tests the two agree
/// on, then each kind of disagreement in one sentence - tests the runner
/// never ran after a failed hook (with those hooks' own failures: the
/// failed test just before each run of such tests), and the rest by app.
fn writeCheck(arena: Allocator, w: W, suites: []const SuiteRuns) !void {
    const Gap = struct { title: []const u8, port_fails: u32 = 0, port_passes: u32 = 0 };
    var gaps: std.ArrayList(Gap) = .empty;
    var check: ?Run = null;
    var tests: u32 = 0;
    var agree: u32 = 0;
    var unrun: u32 = 0;
    var hooks: u32 = 0;
    var unrun_apps: u32 = 0;
    for (suites) |s| if (s.suite.kind == .todomvc_port) {
        const cy = s.check orelse continue;
        const port = s.chrome orelse continue;
        check = cy;
        var gap: Gap = .{ .title = s.suite.title };
        var here: u32 = 0;
        const skipped = struct {
            fn f(t: journal.TestRecord) bool {
                return t.status == .FAIL and t.message != null and std.mem.indexOf(u8, t.message.?, mocha_skip_marker) != null;
            }
        }.f;
        for (cy.tests, 0..) |ct, ci| {
            if (ct.status == .NOTRUN) continue;
            tests += 1;
            const port_pass = for (port.tests) |pt| {
                if (std.mem.eql(u8, pt.id, ct.id)) break pt.status == .PASS;
            } else false;
            const cy_pass = ct.status == .PASS;
            // The failed hook that began a run of skipped tests.
            const hook = ct.status == .FAIL and !skipped(ct) and ci + 1 < cy.tests.len and skipped(cy.tests[ci + 1]);
            if (cy_pass == port_pass) {
                agree += 1;
            } else if (skipped(ct)) {
                here += 1;
            } else if (hook and port_pass) {
                hooks += 1;
            } else if (cy_pass) gap.port_fails += 1 else gap.port_passes += 1;
        }
        unrun += here;
        unrun_apps += @intFromBool(here > 0);
        if (gap.port_fails + gap.port_passes > 0) try gaps.append(arena, gap);
    };
    const c = check orelse return;
    try w.writeAll(" The port was checked test by test against TodoMVC&#39;s own Cypress suite in Chrome (run <code>");
    try html.text(w, c.label);
    try w.writeAll("</code>");
    if (c.pages.len > 0) if (c.pages[0].imported) |im| {
        try w.writeAll(", ");
        try html.text(w, im.date);
    };
    try w.writeAll("): the two agree on ");
    try html.num(w, agree);
    try w.writeAll(" of ");
    try html.plural(w, tests, "test", "tests");
    try w.writeAll(".");
    if (unrun > 0) {
        try w.writeAll(" Cypress did not run ");
        try html.num(w, unrun);
        try w.writeAll(" of the others, in ");
        try html.plural(w, unrun_apps, "app", "apps");
        try w.writeAll(", because a hook had failed earlier in their suite and Mocha skips the rest of it");
        if (hooks == 1) try w.writeAll(", and 1 more is such a hook&#39;s own failure") else if (hooks > 1) try w.print(", and {d} more are those hooks&#39; own failures", .{hooks});
        try w.writeAll("; the port ran them and they passed.");
    }
    std.mem.sort(Gap, gaps.items, {}, struct {
        fn lt(_: void, a: Gap, b: Gap) bool {
            const na = a.port_fails + a.port_passes;
            const nb = b.port_fails + b.port_passes;
            if (na != nb) return na > nb;
            return std.ascii.lessThanIgnoreCase(a.title, b.title);
        }
    }.lt);
    for ([_]bool{ true, false }) |fails| {
        var n: u32 = 0;
        var total: u32 = 0;
        var k: usize = 0;
        for (gaps.items) |g| {
            const count = if (fails) g.port_fails else g.port_passes;
            n += @intFromBool(count > 0);
            total += count;
        }
        if (n == 0) continue;
        try w.writeAll(" ");
        for (gaps.items) |g| {
            const count = if (fails) g.port_fails else g.port_passes;
            if (count == 0) continue;
            if (k > 0) try w.writeAll(if (k + 1 == n) " and " else ", ");
            k += 1;
            try html.text(w, g.title);
            try w.print(" {d}", .{count});
        }
        if (fails) {
            try w.writeAll(if (total == 1) " fails in the port and passes in Cypress" else " fail in the port and pass in Cypress");
        } else try w.writeAll(if (total == 1) " passes in the port and fails in Cypress" else " pass in the port and fail in Cypress");
        try w.writeAll(": the port&#39;s harness and Cypress&#39;s differ there in timing or focus.");
    }
    if (c.pages.len > 0) if (c.pages[0].imported) |im| {
        try w.writeAll(" That run: ");
        try html.text(w, im.runner);
        try w.writeAll(".");
    };
}

pub fn writeIndex(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns, rows: []const Row, o: Options, card_ref: []const u8) !void {
    try writeHead(w, arena, rows, o, card_ref);
    // The headline, as the progress page opens: the frameworks' own tests
    // passing in Crane, then their counts.
    var own: journal.Counts = .{};
    var own_chrome: journal.Counts = .{};
    var running: u32 = 0;
    var waiting: u32 = 0;
    for (rows) |r| {
        if (r.waits != null) {
            waiting += 1;
            continue;
        }
        if (std.mem.eql(u8, r.id, "todomvc")) continue;
        running += 1;
        if (r.crane) |c| own.merge(c);
        if (r.chrome) |c| own_chrome.merge(c);
    }
    var apps: u32 = 0;
    for (suites) |s| apps += @intFromBool(s.suite.kind == .todomvc_port);
    try w.writeAll("<header class=\"head\">\n<h1>Crane <span class=\"h1-rest\">Frameworks</span></h1>\n<div class=\"headline\">\n<p class=\"headline-figure\">");
    try html.num(w, own.pass);
    try w.writeAll("<span class=\"hl-of\"> / ");
    try html.num(w, own.ran());
    try w.writeAll("</span></p>\n<p class=\"headline-label\">The frameworks&#39; own tests passing in Crane</p>\n<dl class=\"headline-counts\">");
    try w.print("<div class=\"{s}\"><dt>Failed</dt><dd>", .{if (own.fail > 0) "fail" else ""});
    try html.num(w, own.fail);
    try w.print("</dd></div><div><dt>Frameworks run</dt><dd>{d}</dd></div><div class=\"{s}\"><dt>Waiting for CDP</dt><dd>{d}</dd></div><div><dt>TodoMVC apps</dt><dd>{d}</dd></div></dl>\n", .{ running, if (waiting > 0) "blk" else "", waiting, apps });
    if (own_chrome.ran() > 0) {
        try w.writeAll("<p class=\"fig-ref\">Chrome <b>");
        try html.num(w, own_chrome.pass);
        try w.writeAll("</b> / ");
        try html.num(w, own_chrome.ran());
        try w.writeAll(" passing, by each project&#39;s own runner.</p>\n");
    }
    try w.print("</div>\n<p class=\"subtitle\">Do JavaScript frameworks work in Crane? Each framework&#39;s own browser tests, and the TodoMVC apps built with them, run in Crane and in Chrome.</p>\n<dl class=\"head-meta\"><div><dt>More</dt><dd><a href=\"{s}\">WPT results</a> &middot; <a href=\"{s}performance/\">Performance</a></dd></div></dl>\n</header>\n", .{ o.assets, o.assets });
    try writeRates(arena, w, rows);
    try writeTodoMvc(arena, w, m, suites);
    try writeNotRun(arena, w, m, suites, rows);
    try writeMethod(arena, w, m, suites);
    try w.writeAll(page_foot);
    // The rail, as on the progress page: names and section numbers only.
    try w.writeAll("<nav class=\"toc\" aria-labelledby=\"toc-title\">\n<p class=\"toc-title\" id=\"toc-title\">Contents</p>\n<ol class=\"toc-list\">\n<li class=\"toc-front\"><a href=\"#main\"><span class=\"secno\"></span><span class=\"toc-name\">Framework totals</span></a></li>\n<li><a href=\"#rates\"><span class=\"secno\">1</span><span class=\"toc-name\">Pass rate per framework</span></a></li>\n");
    for (rows, 1..) |r, k| {
        try w.writeAll("<li><a href=\"#r-");
        try html.text(w, r.id);
        try w.print("\"><span class=\"secno\">1.{d}</span><span class=\"toc-name\">", .{k});
        try html.text(w, r.title);
        try w.writeAll("</span></a></li>\n");
    }
    if (apps > 0) try w.print("<li><a href=\"#todomvc\"><span class=\"secno\">2</span><span class=\"toc-name\">TodoMVC apps</span><span class=\"toc-count\">{d}</span></a></li>\n", .{apps});
    try w.print("<li><a href=\"#not-run\"><span class=\"secno\">3</span><span class=\"toc-name\">What is not run, and why</span></a></li>\n<li><a href=\"#method\"><span class=\"secno\">4</span><span class=\"toc-name\">How this was measured</span></a></li>\n<li class=\"toc-back\"><a href=\"{s}\"><span class=\"secno\"></span><span class=\"toc-name\">WPT results</span></a></li>\n<li><a href=\"{s}performance/\"><span class=\"secno\"></span><span class=\"toc-name\">Performance</span></a></li>\n</ol>\n</nav>\n</div>\n</body>\n</html>\n", .{ o.assets, o.assets });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

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
/// Angular (counts only from Chrome's runner), htmx (no Chrome run), jQuery,
/// React, Svelte and Vue waiting, and three TodoMVC apps (one not served).
fn fixture(a: Allocator) !struct { m: manifest.Manifest, suites: []SuiteRuns } {
    const ng = suiteOf("angular-jasmine", "angular", "Angular", "22.2.6", .project, &.{ .{ .id = "core", .path = "?a" }, .{ .id = "zone", .path = "?b" } });
    const hx = suiteOf("htmx-mocha", "htmx", "htmx", "4.0.1", .project, &.{.{ .id = "test", .path = "test/test.html" }});
    const jq = suiteOf("jquery-qunit", "jquery", "jQuery", "4.0.0", .project, &.{ .{ .id = "css", .path = "test/?module=css" }, .{ .id = "core", .path = "test/?module=core" } });
    var react_app = suiteOf("react-todomvc", "react", "React", "ff43b02e59df", .todomvc_port, &.{.{ .id = "todomvc", .path = "p" }});
    react_app.app = .{ .id = "react", .title = "React", .folder = "react/dist", .version = "19.2.5", .sha256 = &sha };
    var gwt_app = suiteOf("gwt-todomvc", "gwt", "GWT", "ff43b02e59df", .todomvc_port, &.{.{ .id = "todomvc", .path = "p" }});
    gwt_app.app = .{ .id = "gwt", .title = "GWT", .folder = "gwt", .sha256 = &sha, .skipped_by_todomvc = "it deviates" };
    var jq_app = suiteOf("jquery-todomvc", "jquery", "jQuery", "3.6.4", .todomvc_port, &.{.{ .id = "todomvc", .path = "p" }});
    jq_app.app = .{ .id = "jquery", .title = "jQuery", .folder = "jquery/dist", .cypress_framework = "jquery/dist", .sha256 = &sha };
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
        .suites = try a.dupe(manifest.Suite, &.{ jq, hx, ng, react_app, gwt_app, jq_app }),
        .todomvc = .{ .repository = "https://github.com/tastejs/todomvc", .commit = "ff43b02e59dfa604386bb382034b2cd07c2bcd8a", .licence = "MIT", .runner = "QUnit 2.24.2", .reader = .qunit, .source = .{ .url = "https://x", .sha256 = &sha }, .page = "p", .excluded = "todomvc-port.txt", .apps = try a.dupe(manifest.App, &.{
            react_app.app.?, gwt_app.app.?, jq_app.app.?, .{ .id = "somajs", .title = "soma.js", .folder = "somajs", .not_served = "404 on todomvc.com itself" },
        }) },
    };
    var f: Fixture = .{};
    const cr = "crane-1";
    const ch = "chrome-1";
    const imported: journal.Imported = .{ .runner = "bazel test <target>_chromium", .log = "tmp/ng.log", .log_sha256 = &sha, .date = "2026-11-14" };
    // Angular: 997 of 1,000 in Crane; Chrome's runner counts 1,099 of 1,100.
    try f.testRec(a, cr, null, ng, "core", "DI perf events should not crash", .FAIL, .{ .message = "Error: <spyOn> : timeStamp() method does not exist" });
    try f.testRec(a, cr, null, ng, "core", "router view transitions", .FAIL, .{ .message = "NotSupportedError" });
    try f.testRec(a, cr, null, ng, "core", "WebMCP fill out", .FAIL, .{ .message = "TypeError: getTools" });
    try f.testRec(a, cr, null, ng, "core", "core scrolls", .NOTRUN, .{ .not_run = .rendering, .reason = "asserts scrollY" });
    try f.pageRec(a, cr, null, ng, "core", .{ .unnamed_passed = 997 });
    try f.pageRec(a, ch, "Chrome for Testing headless shell 159.0.8154.2", ng, "core", .{ .unnamed_passed = 1099, .unnamed_failed = 1, .reported_total = 1100, .imported = imported });
    // htmx: 1 of 2 in Crane, no Chrome run.
    try f.testRec(a, cr, null, hx, "test", "swap() triggers view transition events", .FAIL, .{});
    try f.testRec(a, cr, null, hx, "test", "swap() swaps", .PASS, .{});
    try f.pageRec(a, cr, null, hx, "test", .{});
    // jQuery: 995 of 1,000 in Crane, 997 of 1,000 in Chrome; an earlier run.
    try f.testRec(a, "crane-0", null, jq, "css", "css: Do not append px", .PASS, .{});
    try f.pageRec(a, "crane-0", null, jq, "css", .{});
    try f.testRec(a, cr, null, jq, "css", "css: fill-opacity", .FAIL, .{ .message = "Do not append px to 'fill-opacity' Expected: 1 Result: undefined" });
    try f.testRec(a, cr, null, jq, "core", "core: jQuery.parseXML - error reporting", .FAIL, .{ .message = "reports error column" });
    try f.pageRec(a, cr, null, jq, "css", .{ .unnamed_passed = 500, .unnamed_failed = 2 });
    try f.pageRec(a, cr, null, jq, "core", .{ .unnamed_passed = 495, .unnamed_failed = 1 });
    try f.testRec(a, ch, chrome_157, jq, "test", "core: jQuery.parseXML - error reporting", .FAIL, .{ .message = "reports error column" });
    try f.pageRec(a, ch, chrome_157, jq, "test", .{ .unnamed_passed = 997, .unnamed_failed = 2, .reported_total = 1000, .imported = .{ .runner = "jquery-test-runner 0.3.0", .log = "tmp/jtr.log", .log_sha256 = &sha, .date = "2026-11-14" } });
    // TodoMVC: React passes everything in both; GWT fails 2 in Crane and 1
    // in Chrome (the port in Chrome); jQuery fails everything in both.
    for ([_]manifest.Suite{ react_app, gwt_app, jq_app }) |s| for ([_][]const u8{ cr, ch }) |label| {
        const b: ?[]const u8 = if (std.mem.eql(u8, label, ch)) chrome_157 else null;
        const is_chrome = b != null;
        const gwt = std.mem.eql(u8, s.id, "gwt-todomvc");
        const jqa = std.mem.eql(u8, s.id, "jquery-todomvc");
        try f.testRec(a, label, b, s, "todomvc", "New Todo: should add", if (jqa or (gwt and !is_chrome)) .FAIL else .PASS, .{});
        try f.testRec(a, label, b, s, "todomvc", "No Todos: starts with nothing", if (jqa) .FAIL else .PASS, .{});
        try f.testRec(a, label, b, s, "todomvc", "Routing: should respect the back button", if (jqa or gwt) .FAIL else .PASS, .{});
        try f.testRec(a, label, b, s, "todomvc", "Persistence: should persist", .NOTRUN, .{ .not_run = .project_skip });
        try f.pageRec(a, label, b, s, "todomvc", .{});
    };
    // TodoMVC's own Cypress run, the port's check: it agrees but for GWT,
    // where a hook fails, Mocha leaves the next test unrun, and one passes in
    // Cypress only.
    for ([_]manifest.Suite{ react_app, gwt_app, jq_app }) |s| {
        const gwt = std.mem.eql(u8, s.id, "gwt-todomvc");
        const jqa = std.mem.eql(u8, s.id, "jquery-todomvc");
        try f.testRec(a, "cy-1", chrome_157, s, "todomvc", "New Todo: should add", if (jqa or gwt) .FAIL else .PASS, .{});
        try f.testRec(a, "cy-1", chrome_157, s, "todomvc", "No Todos: starts with nothing", if (jqa or gwt) .FAIL else .PASS, .{ .message = if (gwt) "Cypress did not run it: a hook failed earlier in its suite, and Mocha skips the suite's remaining tests" else null });
        try f.testRec(a, "cy-1", chrome_157, s, "todomvc", "Routing: should respect the back button", if (jqa) .FAIL else .PASS, .{});
        try f.testRec(a, "cy-1", chrome_157, s, "todomvc", "Persistence: should persist", .NOTRUN, .{ .not_run = .project_skip });
        try f.pageRec(a, "cy-1", chrome_157, s, "todomvc", .{ .imported = .{ .runner = "Cypress 15.14.2", .log = "tmp/cy", .log_sha256 = &sha, .date = "2026-11-14" } });
    }
    const j: journal.Journal = .{ .tests = f.tests.items, .pages = f.pages.items };
    const files = [_][]const exclusions.Entry{ &.{}, &.{.{ .id = "test/a.js", .file = true, .kind = .node_runner_only, .why = "only its Node runner loads it", .line = 1 }}, &.{}, &.{}, &.{}, &.{} };
    return .{ .m = m, .suites = try collect(a, m, &.{j}, &files) };
}

test "what is not run: tests golden rule 2 decides, by kind and framework, apart from rendering" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const flight = suiteOf("react-flight", "react", "React", "19.3.1", .project, &.{.{ .id = "flight", .path = "fixtures/flight" }});
    const ng = suiteOf("angular-jasmine", "angular", "Angular", "22.2.6", .project, &.{.{ .id = "zone", .path = "?z" }});
    const m: manifest.Manifest = .{ .frameworks = &.{ .{ .id = "angular", .title = "Angular" }, .{ .id = "react", .title = "React" } }, .suites = try a.dupe(manifest.Suite, &.{ flight, ng }) };
    var f: Fixture = .{};
    try f.testRec(a, "fw2-1", null, flight, "flight", "smoke test", .NOTRUN, .{ .not_run = .follows_majority, .reason = "fetch() cancelled at a navigation's start (integrator ruling 2026-11-14)" });
    try f.pageRec(a, "fw2-1", null, flight, "flight", .{});
    try f.testRec(a, "fw2-1", null, ng, "zone", "Zone should surface", .NOTRUN, .{ .not_run = .follows_spec, .reason = "PromiseRejectionEventInit.promise is object (angular/angular#72159)" });
    try f.testRec(a, "fw2-1", null, ng, "zone", "Zone passes", .PASS, .{});
    try f.pageRec(a, "fw2-1", null, ng, "zone", .{});
    const j: journal.Journal = .{ .tests = f.tests.items, .pages = f.pages.items };
    const suites = try collect(a, m, &.{j}, &.{ &.{}, &.{} });
    var out: Io.Writer.Allocating = .init(a);
    try writeNotRun(a, &out.writer, m, suites, try chartRows(a, m, suites));
    const h = out.written();
    try testing.expect(std.mem.indexOf(u8, h, "following a ruling 2 tests") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<strong>Crane follows the browsers or the newer spec.</strong>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "The browser majority, by a recorded ruling: 1 test (React 1).") != null);
    // A follows-spec test is the spec's answer a shipping browser gives: a newer spec (Angular's) or a choice the
    // spec leaves to the implementation (React's FragmentRefs side), so the sentence says "the spec" (the
    // integrator, 2026-11-23 1:18 AM ET).
    try testing.expect(std.mem.indexOf(u8, h, " The spec, which a shipping browser follows: 1 test (Angular 1).") != null);
    try testing.expect(std.mem.indexOf(u8, h, "The newer spec, which") == null);
    // Not rendering: that bullet counts none of them.
    try testing.expect(std.mem.indexOf(u8, h, "Not run for this reason") == null);
}

test "React's Jest suite: jsdom's run is the reference, never the Chrome column; React's row draws three meters, every other row two; the method names jsdom's run" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var jest = suiteOf("react-jest", "react", "React", "19.3.1", .project, &.{.{ .id = "jest", .path = "packages" }});
    jest.reader = .runner_report;
    jest.note = "React's own Jest suite runs on jsdom in React's CI.";
    const jq = suiteOf("jquery-qunit", "jquery", "jQuery", "4.0.0", .project, &.{.{ .id = "core", .path = "test/?module=core" }});
    const m: manifest.Manifest = .{ .frameworks = &.{ .{ .id = "jquery", .title = "jQuery" }, .{ .id = "react", .title = "React" } }, .suites = try a.dupe(manifest.Suite, &.{ jq, jest }) };
    const jsdom = "jsdom 26.1.0 (React's yarn test: Jest 30.4.2, Node 20.19.0)";
    var f: Fixture = .{};
    // Crane 2 of 3, Chrome 1 of 3, jsdom 3 of 3.
    for ([_][]const u8{ "a > one", "a > two" }) |id| try f.testRec(a, "k-1", null, jest, "jest", id, .PASS, .{});
    try f.testRec(a, "k-1", null, jest, "jest", "a > three", .FAIL, .{});
    try f.pageRec(a, "k-1", null, jest, "jest", .{});
    try f.testRec(a, "c-1", chrome_157, jest, "jest", "a > one", .PASS, .{});
    for ([_][]const u8{ "a > two", "a > three" }) |id| try f.testRec(a, "c-1", chrome_157, jest, "jest", id, .FAIL, .{});
    try f.pageRec(a, "c-1", chrome_157, jest, "jest", .{});
    for ([_][]const u8{ "a > one", "a > two", "a > three" }) |id| try f.testRec(a, "j-1", jsdom, jest, "jest", id, .PASS, .{});
    try f.pageRec(a, "j-1", jsdom, jest, "jest", .{});
    try f.testRec(a, "k-1", null, jq, "core", "core: x", .PASS, .{});
    try f.pageRec(a, "k-1", null, jq, "core", .{});
    try f.testRec(a, "c-1", chrome_157, jq, "core", "core: x", .PASS, .{});
    try f.pageRec(a, "c-1", chrome_157, jq, "core", .{});
    const j: journal.Journal = .{ .tests = f.tests.items, .pages = f.pages.items };
    const suites = try collect(a, m, &.{j}, &.{ &.{}, &.{} });
    // The jsdom run fills the reference slot, never Chrome's, whatever its label's order.
    try testing.expectEqualStrings(chrome_157, suites[1].chrome.?.browser.?);
    try testing.expectEqualStrings(jsdom, suites[1].reference.?.browser.?);
    try testing.expect(suites[0].reference == null);
    const rows = try chartRows(a, m, suites);
    try testing.expectEqual(@as(u32, 3), rows[1].reference.?.pass);
    try testing.expectEqual(@as(u32, 1), rows[1].chrome.?.pass);
    try testing.expect(rows[0].reference == null);
    var out: Io.Writer.Allocating = .init(a);
    try writeRates(a, &out.writer, rows);
    const h = out.written();
    // One reference meter, in React's row, with its own key; the Crane - Chrome cell stays Crane's and Chrome's.
    try testing.expectEqual(@as(usize, 1), occurrences(h, "<div class=\"fr-bar r\"><span class=\"fr-who\">jsdom</span>"));
    try testing.expectEqual(@as(usize, 1), occurrences(h, "class=\"meter ref\""));
    try testing.expectEqual(@as(usize, 2), occurrences(h, "<span class=\"fr-who\">Chrome</span>"));
    try testing.expect(std.mem.indexOf(u8, h, "<li><span class=\"key key-ref\"></span>jsdom, React&#39;s CI</li>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "data-v=\"33.33\">+33.3") != null);
    // A page with no reference run has no reference key.
    var plain: Io.Writer.Allocating = .init(a);
    try writeRates(a, &plain.writer, rows[0..1]);
    try testing.expect(std.mem.indexOf(u8, plain.written(), "key-ref") == null);
    // The method names jsdom's run beside Chrome's, then the suite's note.
    var method: Io.Writer.Allocating = .init(a);
    try writeMethod(a, &method.writer, m, suites);
    const mh = method.written();
    try testing.expect(std.mem.indexOf(u8, mh, "jsdom: jsdom 26.1.0 (React&#39;s yarn test: Jest 30.4.2, Node 20.19.0), pinned by sha256 <code>") != null);
    try testing.expect(std.mem.indexOf(u8, mh, "run <code>j-1</code>. React&#39;s own Jest suite runs on jsdom in React&#39;s CI.") != null);
}

test "the chart's rows: the frameworks Crane runs A to Z, TodoMVC's apps as one row, then those that wait A to Z; every number from the journals" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    const rows = try chartRows(a, fx.m, fx.suites);
    try testing.expectEqual(@as(usize, 7), rows.len);
    const want = [_][]const u8{ "angular", "htmx", "jquery", "todomvc", "react", "svelte", "vue" };
    for (want, rows) |id, r| try testing.expectEqualStrings(id, r.id);
    // Angular: Crane's named failures and unnamed passes; Chrome's counts.
    try testing.expectEqual(@as(u32, 997), rows[0].crane.?.pass);
    try testing.expectEqual(@as(u32, 1000), rows[0].crane.?.ran());
    try testing.expectEqual(@as(u32, 1099), rows[0].chrome.?.pass);
    try testing.expectEqualStrings("22.2.6 \u{b7} its own tests", rows[0].sub);
    try testing.expect(rows[1].chrome == null);
    // TodoMVC: three apps together, Crane 3 + 1 + 0 of 9, Chrome 3 + 2 + 0.
    try testing.expectEqual(@as(u32, 4), rows[3].crane.?.pass);
    try testing.expectEqual(@as(u32, 9), rows[3].crane.?.ran());
    try testing.expectEqual(@as(u32, 5), rows[3].chrome.?.pass);
    try testing.expectEqualStrings("all 3 apps\u{2019} tests", rows[3].sub);
    // Waiting: CDP when any suite needs only CDP.
    try testing.expectEqual(manifest.Protocol.cdp, rows[6].waits.?);
    try testing.expectEqual(manifest.Protocol.cdp, rows[4].waits.?);
}

test "the chart's axis is one linear 0-100% scale: a rate's length is the rate, no break, no zoom (the user, 2026-11-14 8:15 PM ET)" {
    // The scale itself.
    try testing.expectEqual(@as(f64, 0), xOf(0));
    try testing.expectEqual(@as(f64, 0.5), xOf(50));
    try testing.expectEqual(@as(f64, 1), xOf(100));
    try testing.expectApproxEqAbs(@as(f64, 0.997), xOf(99.7), 1e-12);
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    const out = try render(a, fx.m, fx.suites, .{});
    const h = out.index_html;
    const chart = h[std.mem.indexOf(u8, h, "<section class=\"fw-sec\" id=\"rates\"").?..std.mem.indexOf(u8, h, "<section class=\"fw-sec\" id=\"todomvc\"").?];
    // Each meter's green is its rate and its red the rest: Angular 997 /
    // 1,000 and 1,099 / 1,100; htmx 1 / 2, half way; TodoMVC 4 / 9 and 5 / 9.
    for ([_][]const u8{
        "<span class=\"m-clean\" style=\"width:99.70%\"></span><span class=\"m-fail\" style=\"width:0.30%\"></span>",
        "<span class=\"m-clean\" style=\"width:99.91%\"></span><span class=\"m-fail\" style=\"width:0.09%\"></span>",
        "<span class=\"m-clean\" style=\"width:50.00%\"></span><span class=\"m-fail\" style=\"width:50.00%\"></span>",
        "<span class=\"m-clean\" style=\"width:44.44%\"></span><span class=\"m-fail\" style=\"width:55.56%\"></span>",
        "<span class=\"m-clean\" style=\"width:55.56%\"></span><span class=\"m-fail\" style=\"width:44.44%\"></span>",
    }) |want| {
        if (std.mem.indexOf(u8, chart, want) == null) {
            std.debug.print("not in the chart: {s}\n", .{want});
            return error.TestUnexpectedResult;
        }
    }
    // The scale under the bars: 0, 25, 50, 75 and 100%, nothing else.
    try testing.expect(std.mem.indexOf(u8, chart, "<text x=\"0.00%\" y=\"14\" text-anchor=\"start\">0%</text><text class=\"q\" x=\"25.00%\" y=\"14\" text-anchor=\"middle\">25%</text><text x=\"50.00%\" y=\"14\" text-anchor=\"middle\">50%</text><text class=\"q\" x=\"75.00%\" y=\"14\" text-anchor=\"middle\">75%</text><text x=\"100.00%\" y=\"14\" text-anchor=\"end\">100%</text>") != null);
    try testing.expectEqual(@as(usize, 5), occurrences(chart, "<text "));
    // No break, no zoom, and no note about either.
    for ([_][]const u8{ "class=\"brk\"", "//", "zoomed", "axis-note", "broken" }) |gone| {
        if (std.mem.indexOf(u8, chart, gone) != null) {
            std.debug.print("in the chart: {s}\n", .{gone});
            return error.TestUnexpectedResult;
        }
    }
}

test "a row that leaves tests out says how many and why, linked to section 3; a run that counts nothing says none counted" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    var one: NotCounted = .{};
    one.n[@backingInt(journal.NotRun.rendering)] = 8;
    try writeNotCounted(&out.writer, one, false);
    try testing.expectEqualStrings("<div class=\"fr-note\"><a href=\"#not-run\">8 not run: need a renderer</a></div>", out.written());
    out.clearRetainingCapacity();
    var mixed: NotCounted = .{};
    mixed.n[@backingInt(journal.NotRun.rendering)] = 15;
    mixed.n[@backingInt(journal.NotRun.follows_majority)] = 4;
    mixed.n[@backingInt(journal.NotRun.follows_spec)] = 2;
    mixed.n[@backingInt(journal.NotRun.project_skip)] = 1;
    try writeNotCounted(&out.writer, mixed, false);
    try testing.expectEqualStrings("<div class=\"fr-note\"><a href=\"#not-run\">22 not run: 15 need a renderer, 6 follow a ruling, 1 skipped by the project</a></div>", out.written());
    out.clearRetainingCapacity();
    var app_skips: NotCounted = .{};
    app_skips.n[@backingInt(journal.NotRun.project_skip)] = 45;
    try writeNotCounted(&out.writer, app_skips, true);
    try testing.expectEqualStrings("<div class=\"fr-note\"><a href=\"#not-run\">45 not run: skipped by the apps&#39; spec</a></div>", out.written());
    out.clearRetainingCapacity();
    try writeNotCounted(&out.writer, .{}, false);
    try testing.expectEqualStrings("", out.written());
    // React's: every test it ran is listed - none counted, not "no run".
    try testing.expectEqualStrings("<a href=\"#not-run\">none counted</a>", noRate(.{ .rendering = 26, .not_run = 1 }, true));
    try testing.expectEqualStrings("<a href=\"#not-run\">none counted</a>", noRate(.{ .rendering = 26, .not_run = 1 }, false));
    try testing.expectEqualStrings("no run yet", noRate(null, true));
    try testing.expectEqualStrings("no run", noRate(null, false));
    // A run whose tests all timed out is no "none counted".
    try testing.expectEqualStrings("no run yet", noRate(.{ .timeout = 3 }, true));
}

test "one page in the site's frame: headline, rates, TodoMVC, what is not run and the method closed, the rail; no subpage, no failure name, every rate from the journals" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    const out = try render(a, fx.m, fx.suites, .{});
    const h = out.index_html;
    // The progress page's frame: the document, then the rail.
    const doc = std.mem.indexOf(u8, h, "<div class=\"frame\">\n<main class=\"doc fw\" id=\"main\">").?;
    const rail = std.mem.indexOf(u8, h, "<nav class=\"toc\" aria-labelledby=\"toc-title\">").?;
    try testing.expect(doc < rail);
    // The headline: the frameworks' own tests in Crane (997 + 1 + 995 of
    // 1,000 + 2 + 1,000), failed in red, the waiting count in grey.
    try testing.expect(std.mem.indexOf(u8, h, "<p class=\"headline-figure\">1,993<span class=\"hl-of\"> / 2,002</span></p>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<div class=\"fail\"><dt>Failed</dt><dd>9</dd></div><div><dt>Frameworks run</dt><dd>3</dd></div><div class=\"blk\"><dt>Waiting for CDP</dt><dd>3</dd></div><div><dt>TodoMVC apps</dt><dd>3</dd></div>") != null);
    // The order of the page: numbered sections.
    const rates = std.mem.indexOf(u8, h, "<section class=\"fw-sec\" id=\"rates\"").?;
    const todo = std.mem.indexOf(u8, h, "<section class=\"fw-sec\" id=\"todomvc\"").?;
    const notrun = std.mem.indexOf(u8, h, "<details class=\"fold fw-sec\" id=\"not-run\">").?;
    const method = std.mem.indexOf(u8, h, "<details class=\"fold fw-sec\" id=\"method\">").?;
    try testing.expect(rates < todo and todo < notrun and notrun < method and method < rail);
    for ([_][]const u8{ "<span class=\"secno\">1</span>Pass rate per framework", "<span class=\"secno\">2</span>TodoMVC apps", "<span class=\"secno\">3</span>What is not run, and why", "<span class=\"secno\">4</span>How this was measured" }) |want| try testing.expect(std.mem.indexOf(u8, h, want) != null);
    // Each row once, in order, and in the rail.
    var at: usize = 0;
    for ([_][]const u8{ "angular", "htmx", "jquery", "todomvc", "react", "svelte", "vue" }) |id| {
        const needle = try std.fmt.allocPrint(a, "<div class=\"fr\" id=\"r-{s}\">", .{id});
        try testing.expectEqual(@as(usize, 1), occurrences(h, needle));
        const i = std.mem.indexOf(u8, h, needle).?;
        try testing.expect(i > at);
        at = i;
        try testing.expect(std.mem.indexOf(u8, h[rail..], try std.fmt.allocPrint(a, "<a href=\"#r-{s}\">", .{id})) != null);
    }
    // The rates and counts, from the journals: Angular 997 / 1,000 in a
    // green-and-red meter, Chrome's beside it, the difference in red.
    try testing.expect(std.mem.indexOf(u8, h, "<div class=\"fr-bar\"><span class=\"fr-who\">Crane</span><span class=\"meter\" title=\"Crane: 997 / 1,000 passed (99.7%)\"><span class=\"m-clean\" style=\"width:99.70%\"></span><span class=\"m-fail\" style=\"width:0.30%\"></span></span><span class=\"fr-rate\"><b>99.7%</b><span class=\"fr-n\">997 / 1,000</span></span></div>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<div class=\"fr-diff ratio-bad\" data-v=\"-0.21\">&minus;0.2</div>") != null);
    // Angular's rate leaves out its one rendering test, and its row says so.
    try testing.expect(std.mem.indexOf(u8, h, "<div class=\"fr-note\"><a href=\"#not-run\">1 not run: needs a renderer</a></div>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<span class=\"meter\"></span><span class=\"fr-rate\">no run</span>") != null);
    // A framework that waits: the site's grey block mark and its reason.
    try testing.expectEqual(@as(usize, 3), occurrences(h, "<span class=\"gate g-block\">Can&#39;t run yet &middot; waits for CDP</span>"));
    try testing.expectEqual(@as(usize, 3), occurrences(h, "<span class=\"fr-why\">its test runner drives the browser over CDP, which Crane does not support yet (after 0.1)</span>"));
    // TodoMVC: its figures, then a sortable table with mini meters, highest
    // in Crane first.
    try testing.expect(std.mem.indexOf(u8, h, "<span class=\"fg-pass\">4</span><span class=\"fg-of\">/ 9</span>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<div><dt>Apps passing every test</dt><dd>1 of 3</dd></div>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<table class=\"listing listing-compare fw-apps\">") != null);
    const react_i = std.mem.indexOf(u8, h, "<tr><th scope=\"row\">React</th>").?;
    const gwt_i = std.mem.indexOf(u8, h, "<tr><th scope=\"row\">GWT</th>").?;
    const jq_i = std.mem.indexOf(u8, h, "<tr><th scope=\"row\">jQuery</th>").?;
    try testing.expect(react_i < gwt_i and gwt_i < jq_i);
    try testing.expect(std.mem.indexOf(u8, h, "<td class=\"n\" data-v=\"1\" data-of=\"3\"><span class=\"tally\"><span class=\"mini\"") != null);
    try testing.expect(std.mem.indexOf(u8, h, "soma.js is listed on todomvc.com but cannot be served") != null);
    // The axis note, once; the five-app folder decision, once.
    try testing.expectEqual(@as(usize, 0), occurrences(h, "class=\"axis-note\""));
    try testing.expect(std.mem.indexOf(u8, h, "1 app is given to both as the folder of the build todomvc.com links (<code>jquery/dist</code>)") != null);
    // What Mocha left unrun in Chrome, counted from Chrome's journal.
    // Chrome's column is the port in Chrome; TodoMVC's own Cypress run is
    // its check, stated once in the method, counted from the journals.
    try testing.expect(std.mem.indexOf(u8, h, " The port was checked test by test against TodoMVC&#39;s own Cypress suite in Chrome (run <code>cy-1</code>, 2026-11-14): the two agree on 6 of 9 tests. Cypress did not run 1 of the others, in 1 app, because a hook had failed earlier in their suite and Mocha skips the rest of it, and 1 more is such a hook&#39;s own failure; the port ran them and they passed. GWT 1 fails in the port and passes in Cypress: the port&#39;s harness and Cypress&#39;s differ there in timing or focus. That run: Cypress 15.14.2.") != null);
    try testing.expectEqual(@as(usize, 1), occurrences(h, "TodoMVC&#39;s own Cypress suite"));
    try testing.expect(std.mem.indexOf(u8, h, "Chrome, run <code>chrome-1</code>.") != null or std.mem.indexOf(u8, h, "157.0.8103.78, run <code>chrome-1</code>.") != null);
    // Not run: the counts in its summary.
    try testing.expect(std.mem.indexOf(u8, h, "<span class=\"fold-meta\">rendering 1 test &middot; skipped by TodoMVC&#39;s spec 3 tests</span>") != null);
    // No failure cause, test name or message; no link to a subpage.
    for ([_][]const u8{ "fill-opacity", "parseXML", "timeStamp", "view transition", "should respect the back button", "NotSupportedError", "#fails-only", "href=\"angular/", "href=\"todomvc/" }) |gone| {
        if (std.mem.indexOf(u8, h, gone) != null) {
            std.debug.print("found on the page: {s}\n", .{gone});
            return error.TestUnexpectedResult;
        }
    }
    // Content is HTML; site.js only enhances.
    try testing.expectEqual(@as(usize, 1), occurrences(h, "<script"));
    try testing.expect(std.mem.indexOf(u8, h, "<script src=\"../site.js\" defer></script>") != null);
}

test "the social card's tags: every one present, in the head, the numbers from the journals, the image named by its hash" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    const out = try render(a, fx.m, fx.suites, .{});
    const h = out.index_html;
    const end_head = std.mem.indexOf(u8, h, "</head>").?;
    const description = "Crane passes Angular 99.7%, htmx 50.0%, jQuery 99.5% of the frameworks&#39; own tests (Chrome: Angular 99.9%, jQuery 99.7%); 44.4% of TodoMVC&#39;s apps&#39; tests (Chrome 55.6%); React, Svelte and Vue can&#39;t run yet: they wait for CDP. Crane is a headless web platform engine in Zig.";
    const tags = [_][]const u8{
        "<meta name=\"description\" content=\"" ++ description ++ "\">",
        "<link rel=\"canonical\" href=\"https://zig-whatwg.github.io/crane/frameworks/\">",
        "<meta property=\"og:type\" content=\"website\">",
        "<meta property=\"og:site_name\" content=\"Crane\">",
        "<meta property=\"og:title\" content=\"Crane: JavaScript frameworks\">",
        "<meta property=\"og:description\" content=\"" ++ description ++ "\">",
        "<meta property=\"og:url\" content=\"https://zig-whatwg.github.io/crane/frameworks/\">",
        "<meta property=\"og:image\" content=\"https://zig-whatwg.github.io/crane/frameworks/card.png?v=",
        "<meta property=\"og:image:type\" content=\"image/png\">",
        "<meta property=\"og:image:width\" content=\"1200\">",
        "<meta property=\"og:image:height\" content=\"630\">",
        "<meta property=\"og:image:alt\" content=\"",
        "<meta name=\"twitter:card\" content=\"summary_large_image\">",
        "<meta name=\"twitter:title\" content=\"Crane: JavaScript frameworks\">",
        "<meta name=\"twitter:description\" content=\"" ++ description ++ "\">",
        "<meta name=\"twitter:image\" content=\"https://zig-whatwg.github.io/crane/frameworks/card.png?v=",
    };
    for (tags) |t| {
        const i = std.mem.indexOf(u8, h, t) orelse {
            std.debug.print("missing: {s}\n", .{t});
            return error.TestUnexpectedResult;
        };
        try testing.expect(i < end_head);
    }
    // The ?v= is the card's own hash, the same in both tags.
    const v = try std.fmt.allocPrint(a, "card.png?v={x:0>8}\"", .{@as(u32, @truncate(std.hash.Wyhash.hash(0, out.card_png)))});
    try testing.expectEqual(@as(usize, 2), occurrences(h, v));
    try testing.expect(std.mem.startsWith(u8, out.card_png, "\x89PNG\r\n\x1a\n"));
    // Same journals, same bytes.
    const again = try render(a, fx.m, fx.suites, .{});
    try testing.expectEqualSlices(u8, out.card_png, again.card_png);
    try testing.expectEqualStrings(out.index_html, again.index_html);
}

test "the card's rates are the page's: one formatter, the same text for every count" {
    var a: [16]u8 = undefined;
    var b: [16]u8 = undefined;
    const counts = [_][2]u32{ .{ 13164, 13165 }, .{ 12099, 12126 }, .{ 826, 1202 }, .{ 5, 5 }, .{ 1, 100000 }, .{ 0, 7 } };
    for (counts) |c| try testing.expectEqualStrings(rateText(&a, c[0], c[1]), card.rateOf(c[0], c[1]).?.text(&b));
    // The fixture's card rows carry exactly the rates the page shows.
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const ar = arena_state.allocator();
    const fx = try fixture(ar);
    const rows = try chartRows(ar, fx.m, fx.suites);
    const figures = try cardFigures(ar, rows);
    try testing.expectEqualStrings("99.9%", figures.rows[0].chrome.?.text(&a));
    try testing.expectEqualStrings(rateText(&b, 1099, 1100), figures.rows[0].chrome.?.text(&a));
}

test "rate: one decimal, rounded, never 100% with a failure; nothing run is a dash" {
    var buf: Io.Writer.Allocating = .init(testing.allocator);
    defer buf.deinit();
    const w = &buf.writer;
    try rate(w, 13164, 13165);
    try w.writeAll(" ");
    try rate(w, 12099, 12126);
    try w.writeAll(" ");
    try rate(w, 0, 0);
    try w.writeAll(" ");
    try rate(w, 5, 5);
    try w.writeAll(" ");
    try appRate(w, 28, 29);
    try w.writeAll(" ");
    try appRate(w, 299, 300);
    try testing.expectEqualStrings("&gt;99.9% 99.8% &mdash; 100.0% 97% &gt;99%", buf.written());
}
