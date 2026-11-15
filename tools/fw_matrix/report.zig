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
};

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

/// Where Node runs (the user, 2026-11-11 5:43 PM ET: "we can run node for
/// the purposes of these tests").
pub const node_note =
    "Node runs only the projects' own build steps, test servers and test runners, never inside Crane. jQuery's pages are served by its own test server (jquery-test-runner) with its own dependencies; Angular's are built by its own Bazel and served by its own web-test-runner, one target per page. htmx's test page and the TodoMVC apps are static files, served as they are.";

/// The runs in `journals` grouped by suite, each suite's runs ordered by
/// generation (lane runs, with none, after) then label.
pub fn collect(arena: Allocator, m: manifest.Manifest, journals: []const journal.Journal, file_entries: []const []const exclusions.Entry) ![]SuiteRuns {
    var out: std.ArrayList(SuiteRuns) = .empty;
    for (m.suites, 0..) |s, si| {
        var runs: std.ArrayList(Run) = .empty;
        var chrome: ?Run = null;
        var check: ?Run = null;
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
                    const slot = if (s.kind == .todomvc_port and first.imported != null) &check else &chrome;
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
        try out.append(arena, .{ .suite = s, .runs = runs.items, .file_entries = if (si < file_entries.len) file_entries[si] else &.{}, .chrome = chrome, .check = check });
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
    /// It cannot run yet: the protocol its test runner drives the browser
    /// with, which Crane does not speak.
    waits: ?manifest.Protocol = null,
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
            }
            if (s.chrome) |r| {
                var c = row.chrome orelse journal.Counts{};
                c.merge(r.counts);
                row.chrome = c;
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
// The axis: zoomed to where the rates are, broken between two clusters
// ============================================================================

pub const Segment = struct {
    /// Its range, in percent.
    lo: f64,
    hi: f64,
    /// Its tick step, in percent.
    step: f64,
    /// Where it sits in the plot, as fractions of its width.
    x0: f64,
    x1: f64,
};

pub const Axis = struct {
    segs: [2]Segment,
    n: usize,

    /// The x of a rate as a fraction of the plot's width.
    pub fn x(a: Axis, v: f64) f64 {
        for (a.segs[0..a.n]) |s| if (v >= s.lo - 1e-9 and v <= s.hi + 1e-9) {
            return s.x0 + (v - s.lo) / (s.hi - s.lo) * (s.x1 - s.x0);
        };
        // Outside every segment (never, for the values it was made from).
        return if (v < a.segs[0].lo) a.segs[0].x0 else a.segs[a.n - 1].x1;
    }

    pub fn broken(a: Axis) bool {
        return a.n == 2;
    }
};

/// Two rates further apart than this split the axis.
const cluster_gap = 15.0;
/// The gap between two segments, as a fraction of the plot.
const break_width = 0.07;
const steps = [_]f64{ 0.2, 0.5, 1, 2, 5, 10, 20, 25 };

/// `v` without the float noise of a multiplied step (385 * 0.2).
fn clean(v: f64) f64 {
    return @round(v * 1e6) / 1e6;
}

/// A cluster's range: whole percents around it, at least one percent wide,
/// within 0-100, cut in at most five steps of 1-2-5.
fn segmentFor(min: f64, max: f64) Segment {
    var lo0 = @floor(min);
    var hi0 = @max(@ceil(max), lo0 + 1);
    if (hi0 > 100) {
        lo0 -= hi0 - 100;
        hi0 = 100;
    }
    for (steps) |st| {
        const lo = clean(@floor(lo0 / st + 1e-9) * st);
        const hi = @min(100.0, clean(@ceil(hi0 / st - 1e-9) * st));
        if ((hi - lo) / st <= 5 + 1e-9) return .{ .lo = @max(0, lo), .hi = hi, .step = st, .x0 = 0, .x1 = 1 };
    }
    return .{ .lo = 0, .hi = 100, .step = 20, .x0 = 0, .x1 = 1 };
}

/// The axis for `values` (percentages): one segment around them, or two
/// when they fall in two clusters more than `cluster_gap` points apart, each
/// given room by the rates it holds (at least a quarter of the plot); 0-100
/// when they fall in more than two.
pub fn axisFor(arena: Allocator, values: []const f64) !Axis {
    const whole: Axis = .{ .segs = .{ .{ .lo = 0, .hi = 100, .step = 20, .x0 = 0, .x1 = 1 }, undefined }, .n = 1 };
    if (values.len == 0) return whole;
    const v = try arena.dupe(f64, values);
    std.mem.sort(f64, v, {}, std.sort.asc(f64));
    var splits: usize = 0;
    var cut: usize = 0;
    for (v[1..], 1..) |x, i| if (x - v[i - 1] > cluster_gap) {
        splits += 1;
        cut = i;
    };
    if (splits == 0) return .{ .segs = .{ segmentFor(v[0], v[v.len - 1]), undefined }, .n = 1 };
    if (splits > 1) return whole;
    var a = segmentFor(v[0], v[cut - 1]);
    var b = segmentFor(v[cut], v[v.len - 1]);
    if (a.hi >= b.lo) return .{ .segs = .{ segmentFor(v[0], v[v.len - 1]), undefined }, .n = 1 };
    // Room by the rates each holds (direction A: the crowded 99-100% gets
    // the most), never under a quarter; every tick is labelled, so the two
    // scales are read apart.
    const na: f64 = @floatFromInt(cut);
    const nb: f64 = @floatFromInt(v.len - cut);
    const wa = @max(0.25, na / (na + nb));
    const wb = @max(0.25, 1 - wa);
    const room = 1 - break_width;
    a.x0 = 0;
    a.x1 = room * wa / (wa + wb);
    b.x0 = a.x1 + break_width;
    b.x1 = 1;
    return .{ .segs = .{ a, b }, .n = 2 };
}

/// "99%", "99.2%".
fn tickLabel(buf: []u8, v: f64) []const u8 {
    const r = @round(v * 10) / 10;
    if (@abs(r - @round(r)) < 1e-9) return std.fmt.bufPrint(buf, "{d}%", .{@as(i64, @intFromFloat(@round(r)))}) catch unreachable;
    return std.fmt.bufPrint(buf, "{d:.1}%", .{r}) catch unreachable;
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
    try w.writeAll("</head>\n<body>\n<main class=\"doc fw\" id=\"main\">\n");
}

const style =
    \\<style>
    \\.fw { --crane: #2a78d6; margin: 0 auto; }
    \\@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) .fw { --crane: #3987e5; } }
    \\:root[data-theme="dark"] .fw { --crane: #3987e5; }
    \\.fw .subtitle { max-width: 52rem; }
    \\.fw .vh { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
    \\.fw .rates { margin: 0 0 2.6rem; }
    \\.fw .rates .box-head { align-items: center; flex-wrap: wrap; row-gap: 0.4rem; }
    \\.fw .rates h2.box-title { position: static; }
    \\.fw .fw-key { display: flex; gap: 1.2rem; margin: 0; padding: 0; list-style: none; font: 500 0.84rem/1 var(--sans); color: var(--ink); }
    \\.fw .fw-key li { display: flex; align-items: center; gap: 0.4rem; }
    \\.fw .rows { padding: 0.5rem 1rem 0.2rem; }
    \\.fw .dr { display: grid; grid-template-columns: minmax(8.5rem, 11rem) minmax(0, 1fr) 6.6rem 6.6rem; column-gap: 1.1rem; align-items: center; padding: 0.5rem 0; }
    \\.fw .dr-head { padding: 0 0 0.1rem; font: 600 0.74rem/1.3 var(--sans); color: var(--ink-2); }
    \\.fw .dr-head span { grid-column: 3; text-align: right; }
    \\.fw .dr-head span + span { grid-column: 4; }
    \\.fw .dr-name { min-width: 0; }
    \\.fw .dr-title { display: block; font: 620 1.14rem/1.2 var(--serif); }
    \\.fw .dr-title a { color: inherit; text-decoration: none; }
    \\.fw .dr-sub { display: block; margin-top: 0.1rem; font: 400 0.78rem/1.3 var(--sans); color: var(--ink-2); font-variant-numeric: tabular-nums; }
    \\.fw .plot { display: block; width: 100%; height: 30px; overflow: visible; }
    \\.fw .plot .grid { stroke: var(--rule); stroke-width: 1; }
    \\.fw .plot .track { stroke: var(--rule-strong); stroke-width: 1; }
    \\.fw .plot .link { stroke: color-mix(in srgb, var(--crane) 40%, transparent); stroke-width: 4; stroke-linecap: round; }
    \\.fw .plot .crane { fill: var(--crane); stroke: var(--paper); stroke-width: 2; }
    \\.fw .plot .chrome { fill: var(--paper); stroke: var(--ink-2); stroke-width: 2; }
    \\.fw .plot .brk { stroke: var(--ink-2); stroke-width: 1.2; }
    \\.fw .dr-v { text-align: right; font: 400 0.76rem/1.25 var(--sans); color: var(--ink-2); font-variant-numeric: tabular-nums; white-space: nowrap; }
    \\.fw .dr-v b { display: block; font: 650 1.24rem/1.15 var(--sans); color: var(--ink); }
    \\.fw .dr-v.g b { font-weight: 450; color: var(--ink-2); }
    \\.fw .dr-v .vl { display: none; }
    \\.fw .dr-v.none { font-size: 0.84rem; }
    \\.fw .dr-wait { grid-column: 2 / -1; display: flex; flex-wrap: wrap; align-items: center; gap: 0.35rem 0.8rem; min-height: 30px; padding: 0.3rem 0.5rem; border-radius: 2px;
    \\  background: repeating-linear-gradient(135deg, var(--unrun) 0 5px, transparent 5px 10px); }
    \\.fw .mark-wait { padding: 0.32rem 0.5rem; border-radius: 2px; background: var(--block-wash); color: var(--block); font: 650 0.72rem/1 var(--sans); letter-spacing: 0.04em; text-transform: uppercase; white-space: nowrap; }
    \\.fw .why { padding: 0.05rem 0.3rem; border-radius: 2px; background: var(--paper); font: 400 0.86rem/1.35 var(--sans); color: var(--ink-2); }
    \\.fw .axis { display: block; width: 100%; height: 22px; overflow: visible; font: 400 11px var(--sans); }
    \\.fw .axis text { fill: var(--ink-2); font-variant-numeric: tabular-nums; }
    \\.fw .axis .brk { stroke: var(--ink-2); stroke-width: 1.2; }
    \\.fw .dr-axis { padding-top: 0.15rem; }
    \\.fw .dr-axis .axis { grid-column: 2; }
    \\.fw .axis-note { margin: 0.3rem 1rem 1rem; max-width: var(--measure); font: 400 0.8rem/1.45 var(--sans); color: var(--ink-2); }
    \\.fw details.fold { margin: 0 0 1.2rem; padding-top: 1.1rem; border-top: 1px solid var(--rule); }
    \\.fw details.fold > summary { display: flex; flex-wrap: wrap; align-items: baseline; gap: 0.3rem 1rem; list-style: none; cursor: pointer; }
    \\.fw details.fold > summary::-webkit-details-marker { display: none; }
    \\.fw details.fold > summary h2 { display: inline-flex; align-items: baseline; gap: 0.6rem; margin: 0; font-size: 1.32rem; }
    \\.fw details.fold > summary h2::before { content: ""; flex: none; width: 0.42rem; height: 0.42rem; border-right: 1.4px solid var(--ink-2); border-bottom: 1.4px solid var(--ink-2); transform: translateY(-0.12em) rotate(-45deg); transition: transform 180ms cubic-bezier(0.16, 1, 0.3, 1); }
    \\.fw details.fold[open] > summary h2::before { transform: translateY(-0.2em) rotate(45deg); }
    \\.fw details.fold > summary:hover h2 { color: var(--link); }
    \\.fw .fold-meta { margin-left: auto; font: 400 0.82rem/1.3 var(--sans); color: var(--ink-2); }
    \\.fw .fold-body { padding: 0.9rem 0 0.6rem; }
    \\.fw .fold-body > p, .fw .facts, .fw .method { max-width: var(--measure); }
    \\.fw .allpass { margin: 0 0 1rem; font: 400 1rem/1.4 var(--sans); }
    \\.fw .allpass b { font-weight: 650; font-variant-numeric: tabular-nums; }
    \\.fw .apps { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 3rem; }
    \\.fw .app-list { margin: 0; padding: 0; list-style: none; }
    \\.fw .app { display: grid; grid-template-columns: minmax(6rem, 11rem) minmax(0, 1fr) 3rem 3rem; column-gap: 0.75rem; align-items: center; min-height: 1.72rem; font: 400 0.84rem/1.25 var(--sans); font-variant-numeric: tabular-nums; }
    \\.fw .app-head { min-height: 1.3rem; font: 600 0.7rem/1.2 var(--sans); color: var(--ink-2); }
    \\.fw .app-head span:nth-child(3), .fw .app-head span:nth-child(4) { text-align: right; }
    \\.fw .app-name { text-align: right; font: 400 0.92rem/1.2 var(--serif); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\.fw .app .plot { height: 18px; }
    \\.fw .app .c { text-align: right; font-weight: 650; }
    \\.fw .app .g { text-align: right; color: var(--ink-2); }
    \\.fw .app .none { text-align: right; color: var(--ink-2); }
    \\.fw .app-axis .axis { grid-column: 2; }
    \\.fw .fine { margin: 1rem 0 0; max-width: var(--measure); font: 400 0.84rem/1.45 var(--sans); }
    \\.fw .facts, .fw .method { padding-left: 1.2rem; }
    \\.fw .facts li, .fw .method li { margin: 0 0 0.6rem; }
    \\.fw .note { margin-top: 0.4rem; }
    \\@media (max-width: 40rem) {
    \\  .fw .rows { padding: 0.4rem 0.75rem 0.2rem; }
    \\  .fw .dr { grid-template-columns: minmax(0, 1fr); row-gap: 0.2rem; padding: 0.6rem 0; }
    \\  .fw .dr-head { display: none; }
    \\  .fw .dr-name, .fw .dr .plot, .fw .dr-wait, .fw .dr-v { grid-column: 1 / -1; }
    \\  .fw .dr-v { display: flex; align-items: baseline; gap: 0.45rem; text-align: left; }
    \\  .fw .dr-v b { display: inline; min-width: 4.2rem; font-size: 1.05rem; }
    \\  .fw .dr-v .vl { display: inline; min-width: 3.3rem; font-weight: 600; color: var(--ink-2); }
    \\  .fw .dr-axis { display: block; }
    \\  .fw .axis .minor { display: none; }
    \\  .fw .apps { grid-template-columns: minmax(0, 1fr); }
    \\  .fw .app { grid-template-columns: minmax(5.5rem, 7.5rem) minmax(0, 1fr) 2.8rem 2.8rem; column-gap: 0.5rem; }
    \\  .fw .app-list + .app-list .app-head { display: none; }
    \\  .fw .fold-meta { margin-left: 0; }
    \\}
    \\</style>
    \\
;

const page_foot = "<footer class=\"foot\"><p>Written as HTML by <code>tools/fw_matrix</code> from its journals (<code>crane-fw/1</code>).</p></footer>\n</main>\n</body>\n</html>\n";

/// A circle at a percentage of the plot, with its native tooltip.
fn dot(w: W, class: []const u8, frac: f64, cy: u32, r: u32, title: []const u8) !void {
    try w.print("<circle class=\"{s}\" cx=\"", .{class});
    try pctAttr(w, frac);
    try w.print("\" cy=\"{d}\" r=\"{d}\"><title>", .{ cy, r });
    try html.text(w, title);
    try w.writeAll("</title></circle>");
}

/// The tracks and gridlines of one row's plot on `axis` (height `h`).
fn plotFrame(w: W, axis: Axis, h: u32) !void {
    for (axis.segs[0..axis.n]) |s| {
        var v = s.lo;
        while (v <= s.hi + 1e-9) : (v += s.step) {
            try w.writeAll("<line class=\"grid\" x1=\"");
            try pctAttr(w, axis.x(v));
            try w.writeAll("\" x2=\"");
            try pctAttr(w, axis.x(v));
            try w.print("\" y1=\"3\" y2=\"{d}\"/>", .{h - 3});
        }
        try w.writeAll("<line class=\"track\" x1=\"");
        try pctAttr(w, s.x0);
        try w.writeAll("\" x2=\"");
        try pctAttr(w, s.x1);
        try w.print("\" y1=\"{d}\" y2=\"{d}\"/>", .{ h / 2, h / 2 });
    }
}

/// Two short slants where the axis breaks, centred on `y`.
fn breakMark(w: W, axis: Axis, y: u32) !void {
    if (!axis.broken()) return;
    const mid = (axis.segs[0].x1 + axis.segs[1].x0) / 2;
    try w.writeAll("<svg x=\"");
    try pctAttr(w, mid);
    try w.print("\" y=\"{d}\" overflow=\"visible\"><line class=\"brk\" x1=\"-6\" y1=\"5\" x2=\"-1\" y2=\"-5\"/><line class=\"brk\" x1=\"1\" y1=\"5\" x2=\"6\" y2=\"-5\"/></svg>", .{y});
}

fn writeChart(arena: Allocator, w: W, rows: []const Row) !void {
    var values: std.ArrayList(f64) = .empty;
    for (rows) |r| {
        if (r.crane) |c| if (pct(c)) |v| try values.append(arena, v);
        if (r.chrome) |c| if (pct(c)) |v| try values.append(arena, v);
    }
    const axis = try axisFor(arena, values.items);
    try w.writeAll("<section class=\"box rates\" id=\"rates\" aria-labelledby=\"rates-h\">\n<div class=\"box-head\"><h2 class=\"box-title\" id=\"rates-h\">Pass rate: Crane beside Chrome</h2>\n");
    try w.writeAll("<ul class=\"fw-key\"><li><svg width=\"14\" height=\"14\" aria-hidden=\"true\"><circle cx=\"7\" cy=\"7\" r=\"6\" fill=\"var(--crane)\"/></svg>Crane</li><li><svg width=\"14\" height=\"14\" aria-hidden=\"true\"><circle cx=\"7\" cy=\"7\" r=\"5.5\" fill=\"var(--paper)\" stroke=\"var(--ink-2)\" stroke-width=\"2\"/></svg>Chrome</li></ul></div>\n");
    try w.writeAll("<div class=\"rows\" role=\"list\">\n<div class=\"dr dr-head\" aria-hidden=\"true\"><span>Crane</span><span>Chrome</span></div>\n");
    var buf: [16]u8 = undefined;
    for (rows) |r| {
        try w.writeAll("<div class=\"dr\" role=\"listitem\" id=\"r-");
        try html.text(w, r.id);
        try w.writeAll("\"><div class=\"dr-name\"><span class=\"dr-title\">");
        if (std.mem.eql(u8, r.id, "todomvc")) try w.writeAll("<a href=\"#todomvc\">");
        try html.text(w, r.title);
        if (std.mem.eql(u8, r.id, "todomvc")) try w.writeAll("</a>");
        try w.writeAll("</span><span class=\"dr-sub\">");
        try html.text(w, r.sub);
        try w.writeAll("</span></div>");
        if (r.waits) |p| {
            try w.print("<div class=\"dr-wait\"><span class=\"mark-wait\">can&#39;t run yet &middot; waits for {s}</span><span class=\"why\">its test runner drives the browser over {s}, which Crane does not support yet (after 0.1)</span></div></div>\n", .{ p.short(), p.short() });
            continue;
        }
        // The plot: the line from Crane's rate to Chrome's, the ring, the dot.
        try w.writeAll("<svg class=\"plot\" aria-hidden=\"true\">");
        try plotFrame(w, axis, 30);
        try breakMark(w, axis, 15);
        const cv = if (r.crane) |c| pct(c) else null;
        const gv = if (r.chrome) |c| pct(c) else null;
        if (cv != null and gv != null) {
            try w.writeAll("<line class=\"link\" x1=\"");
            try pctAttr(w, axis.x(cv.?));
            try w.writeAll("\" x2=\"");
            try pctAttr(w, axis.x(gv.?));
            try w.writeAll("\" y1=\"15\" y2=\"15\"/>");
        }
        if (gv) |v| try dot(w, "chrome", axis.x(v), 15, 6, try std.fmt.allocPrint(arena, "Chrome: {s} ({s})", .{ try countsText(arena, r.chrome.?), rateText(&buf, r.chrome.?.pass, r.chrome.?.ran()) }));
        if (cv) |v| try dot(w, "crane", axis.x(v), 15, 7, try std.fmt.allocPrint(arena, "Crane: {s} ({s})", .{ try countsText(arena, r.crane.?), rateText(&buf, r.crane.?.pass, r.crane.?.ran()) }));
        try w.writeAll("</svg>");
        // The numbers, each with its name for a reader who does not see the heads.
        for ([_]?journal.Counts{ r.crane, r.chrome }, 0..) |maybe, i| {
            const cls = if (i == 0) "c" else "g";
            const name = if (i == 0) "Crane" else "Chrome";
            if (maybe) |c| if (c.ran() > 0) {
                try w.print("<div class=\"dr-v {s}\"><span class=\"vl\">{s}</span><span class=\"vh\">{s}: </span><b>", .{ cls, name, name });
                try rate(w, c.pass, c.ran());
                try w.writeAll("</b><span>");
                try html.num(w, c.pass);
                try w.writeAll(" / ");
                try html.num(w, c.ran());
                try w.writeAll("</span></div>");
                continue;
            };
            try w.print("<div class=\"dr-v {s} none\"><span class=\"vl\">{s}</span><span class=\"vh\">{s}: </span>{s}</div>", .{ cls, name, name, if (i == 0) "no run yet" else "no run" });
        }
        try w.writeAll("</div>\n");
    }
    // The axis under the lines: every tick, the breaks marked.
    try w.writeAll("<div class=\"dr dr-axis\" aria-hidden=\"true\"><svg class=\"axis\">");
    var tbuf: [16]u8 = undefined;
    for (axis.segs[0..axis.n], 0..) |s, si| {
        var v = s.lo;
        var k: usize = 0;
        while (v <= s.hi + 1e-9) : ({
            v += s.step;
            k += 1;
        }) {
            const first = k == 0;
            const last = v + s.step > s.hi + 1e-9;
            const anchor = if (first and (si == 0 or axis.broken())) "start" else if (last) "end" else "middle";
            const minor = !first and !last;
            // A narrow part labels its ends only; its other ticks stay lines.
            if (minor and s.x1 - s.x0 < 0.4) continue;
            try w.print("<text{s} x=\"", .{if (minor) " class=\"minor\"" else ""});
            try pctAttr(w, axis.x(v));
            try w.print("\" y=\"14\" text-anchor=\"{s}\">{s}</text>", .{ anchor, tickLabel(&tbuf, v) });
        }
    }
    try breakMark(w, axis, 9);
    try w.writeAll("</svg></div>\n</div>\n");
    // What the axis is, said once.
    try w.writeAll("<p class=\"axis-note\">");
    if (axis.broken()) {
        try w.writeAll("The axis is zoomed to where the rates are, ");
        for (axis.segs[0..2], 0..) |s, i| {
            if (i > 0) try w.writeAll(" and ");
            try w.print("{s}&ndash;", .{tickLabel(&tbuf, s.lo)});
            try w.writeAll(tickLabel(&tbuf, s.hi));
        }
        try w.writeAll(", broken between them: no rate falls in the gap. ");
    } else if (axis.segs[0].lo > 0 or axis.segs[0].hi < 100) {
        try w.print("The axis is zoomed to where the rates are, {s}&ndash;", .{tickLabel(&tbuf, axis.segs[0].lo)});
        try w.print("{s}. ", .{tickLabel(&tbuf, axis.segs[0].hi)});
    }
    try w.writeAll("Pass rate is the tests that passed of the tests run; dots, not bars, so no length is cut short.</p>\n</section>\n");
}

/// The TodoMVC apps by their pass rate in Crane, highest first (then Chrome's,
/// then A to Z), in two columns.
fn writeTodoMvc(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns) !void {
    const App = struct { title: []const u8, crane: ?journal.Counts, chrome: ?journal.Counts, crane_all: bool, chrome_all: bool };
    var apps: std.ArrayList(App) = .empty;
    var crane_all: u32 = 0;
    var chrome_all: u32 = 0;
    var tests_each: ?u32 = null;
    for (suites) |s| if (s.suite.kind == .todomvc_port) {
        const r = latest(s);
        const a: App = .{ .title = s.suite.title, .crane = if (r) |x| x.counts else null, .chrome = if (s.chrome) |x| x.counts else null, .crane_all = if (r) |x| allPass(x) else false, .chrome_all = if (s.chrome) |x| allPass(x) else false };
        crane_all += @intFromBool(a.crane_all);
        chrome_all += @intFromBool(a.chrome_all);
        if (r) |x| if (x.tests.len > 0) {
            tests_each = @intCast(x.tests.len);
        };
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
    var not_served: u32 = 0;
    if (m.todomvc) |t| for (t.apps) |app| {
        not_served += @intFromBool(app.not_served != null);
    };

    try w.print("<details class=\"fold\" id=\"todomvc\" open>\n<summary><h2>TodoMVC: pass rate per app</h2><span class=\"fold-meta\">{d} apps", .{apps.items.len});
    if (tests_each) |n| try w.print(" &middot; {d} tests each", .{n});
    try w.writeAll(" &middot; the same port in both browsers &middot; highest in Crane first</span></summary>\n<div class=\"fold-body\">\n");
    try w.print("<p class=\"allpass\"><b>{d}</b> of {d} apps pass every test in Crane, <b>{d}</b> in Chrome.</p>\n", .{ crane_all, apps.items.len, chrome_all });
    try w.writeAll("<div class=\"apps\">\n");
    const half = (apps.items.len + 1) / 2;
    const zero_to_hundred: Axis = .{ .segs = .{ .{ .lo = 0, .hi = 100, .step = 50, .x0 = 0, .x1 = 1 }, undefined }, .n = 1 };
    var buf: [16]u8 = undefined;
    for ([_][]const App{ apps.items[0..half], apps.items[half..] }) |col| {
        if (col.len == 0) continue;
        try w.writeAll("<ul class=\"app-list\">\n<li class=\"app app-head\" aria-hidden=\"true\"><span></span><span></span><span>Crane</span><span>Chrome</span></li>\n");
        for (col) |a| {
            try w.writeAll("<li class=\"app\"><span class=\"app-name\">");
            try html.text(w, a.title);
            try w.writeAll("</span><svg class=\"plot\" aria-hidden=\"true\">");
            try plotFrame(w, zero_to_hundred, 18);
            const cv = if (a.crane) |c| pct(c) else null;
            const gv = if (a.chrome) |c| pct(c) else null;
            if (cv != null and gv != null and cv.? != gv.?) {
                try w.writeAll("<line class=\"link\" x1=\"");
                try pctAttr(w, cv.? / 100);
                try w.writeAll("\" x2=\"");
                try pctAttr(w, gv.? / 100);
                try w.writeAll("\" y1=\"9\" y2=\"9\"/>");
            }
            if (gv) |v| try dot(w, "chrome", v / 100, 9, 5, try std.fmt.allocPrint(arena, "{s}, Chrome: {s} ({s})", .{ a.title, try countsText(arena, a.chrome.?), rateText(&buf, a.chrome.?.pass, a.chrome.?.ran()) }));
            if (cv) |v| try dot(w, "crane", v / 100, 9, 6, try std.fmt.allocPrint(arena, "{s}, Crane: {s} ({s})", .{ a.title, try countsText(arena, a.crane.?), rateText(&buf, a.crane.?.pass, a.crane.?.ran()) }));
            try w.writeAll("</svg>");
            for ([_]?journal.Counts{ a.crane, a.chrome }, 0..) |maybe, i| {
                const name = if (i == 0) "Crane" else "Chrome";
                if (maybe) |c| if (c.ran() > 0) {
                    try w.print("<span class=\"{s}\"><span class=\"vh\">{s}: </span>", .{ if (i == 0) "c" else "g", name });
                    try appRate(w, c.pass, c.ran());
                    try w.writeAll("</span>");
                    continue;
                };
                try w.print("<span class=\"none\"><span class=\"vh\">{s}: </span>&mdash;</span>", .{name});
            }
            try w.writeAll("</li>\n");
        }
        try w.writeAll("<li class=\"app app-axis\" aria-hidden=\"true\"><span></span><svg class=\"axis\"><text x=\"0%\" y=\"14\" text-anchor=\"start\">0%</text><text x=\"50%\" y=\"14\" text-anchor=\"middle\">50%</text><text x=\"100%\" y=\"14\" text-anchor=\"end\">100%</text></svg></li>\n</ul>\n");
    }
    try w.writeAll("</div>\n");
    if (not_served > 0) {
        try w.writeAll("<p class=\"fine quiet\">");
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
    try w.writeAll("</div>\n</details>\n");
}

/// A whole percent where the rate is one ("100%", "93%"), else one decimal;
/// never 100% with a failure, never 0% with a pass.
fn appRate(w: W, pass: u32, ran: u32) !void {
    const whole = (@as(u64, pass) * 100 + ran / 2) / ran;
    if (pass < ran and whole == 100) return w.writeAll("&gt;99%");
    if (pass > 0 and whole == 0) return w.writeAll("&lt;1%");
    try w.print("{d}%", .{whole});
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
    try w.writeAll("<details class=\"fold\" id=\"not-run\">\n<summary><h2>What is not run, and why</h2><span class=\"fold-meta\">");
    var parts: u32 = 0;
    for ([_]struct { u32, []const u8 }{ .{ rendering, "rendering" }, .{ skipped, "skipped by the projects" }, .{ app_skips, "skipped by TodoMVC&#39;s spec" } }) |p| if (p[0] > 0) {
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
    if (s.suite.note) |note| try html.text(w, note);
}

/// "How this was measured": closed.
fn writeMethod(arena: Allocator, w: W, m: manifest.Manifest, suites: []const SuiteRuns) !void {
    try w.writeAll("<details class=\"fold\" id=\"method\">\n<summary><h2>How this was measured</h2></summary>\n<div class=\"fold-body\">\n<ul class=\"method\">\n");
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
    try w.print("<header class=\"head\">\n<h1>Crane <span class=\"h1-rest\">Frameworks</span></h1>\n<p class=\"subtitle\">Do JavaScript frameworks work in Crane? Each framework&#39;s own browser tests, and the TodoMVC apps built with them, run in Crane and in Chrome. <a href=\"{s}\">WPT results</a> &middot; <a href=\"{s}performance/\">Performance</a></p>\n</header>\n", .{ o.assets, o.assets });
    try writeChart(arena, w, rows);
    try writeTodoMvc(arena, w, m, suites);
    try writeNotRun(arena, w, m, suites, rows);
    try writeMethod(arena, w, m, suites);
    try w.writeAll(page_foot);
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

test "the axis: zoomed to the clusters the rates fall in, broken between two, each labelled" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    // The published page's: two clusters, 76-77% and 99-100%.
    const ax = try axisFor(a, &.{ 99.78, 99.99, 99.89, 99.44, 99.74, 76.4, 76.7 });
    try testing.expect(ax.broken());
    try testing.expectEqual(@as(f64, 76), ax.segs[0].lo);
    try testing.expectEqual(@as(f64, 77), ax.segs[0].hi);
    try testing.expectEqual(@as(f64, 99), ax.segs[1].lo);
    try testing.expectEqual(@as(f64, 100), ax.segs[1].hi);
    try testing.expectEqual(@as(f64, 0.2), ax.segs[1].step);
    // Room by the rates held: five in 99-100, two in 76-77; monotonic.
    try testing.expect(ax.segs[1].x1 - ax.segs[1].x0 > 2 * (ax.segs[0].x1 - ax.segs[0].x0));
    try testing.expect(ax.segs[0].x1 - ax.segs[0].x0 >= 0.25 * (1 - break_width) - 1e-9);
    try testing.expect(ax.x(76.7) < ax.x(99.0) and ax.x(99.5) < ax.x(99.9));
    try testing.expectApproxEqAbs(@as(f64, 1), ax.x(100), 1e-9);
    // Crane and Chrome ten points apart stay one cluster: 65-80 by 5.
    const near = try axisFor(a, &.{ 99.8, 99.9, 99.4, 99.7, 76.4, 66.9 });
    try testing.expect(near.broken());
    try testing.expectEqual(@as(f64, 65), near.segs[0].lo);
    try testing.expectEqual(@as(f64, 80), near.segs[0].hi);
    try testing.expect(near.segs[0].x1 - near.segs[0].x0 < near.segs[1].x1 - near.segs[1].x0);
    // One cluster: one segment around it; all at 100%: 99-100.
    const one = try axisFor(a, &.{ 99.4, 99.8 });
    try testing.expect(!one.broken());
    try testing.expectEqual(@as(f64, 99), one.segs[0].lo);
    try testing.expectEqual(@as(f64, 99), (try axisFor(a, &.{ 100, 100 })).segs[0].lo);
    // A wide cluster takes coarser steps: 62.3-79.9 is 60-80 by 5.
    const wide = try axisFor(a, &.{ 62.3, 66, 70, 75, 79.9 });
    try testing.expectEqual(@as(f64, 60), wide.segs[0].lo);
    try testing.expectEqual(@as(f64, 5), wide.segs[0].step);
    // Three clusters: the whole 0-100.
    const three = try axisFor(a, &.{ 10, 50, 99 });
    try testing.expectEqual(@as(f64, 0), three.segs[0].lo);
    try testing.expectEqual(@as(f64, 100), three.segs[0].hi);
    var buf: [16]u8 = undefined;
    try testing.expectEqualStrings("99.2%", tickLabel(&buf, 99.2));
    try testing.expectEqualStrings("100%", tickLabel(&buf, 100.0000001));
}

test "one page: the chart, TodoMVC open, what is not run and the method closed; no subpage, no failure name, every rate from the journals" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const fx = try fixture(a);
    const out = try render(a, fx.m, fx.suites, .{});
    const h = out.index_html;
    // The order of the page.
    const chart = std.mem.indexOf(u8, h, "<section class=\"box rates\" id=\"rates\"").?;
    const todo = std.mem.indexOf(u8, h, "<details class=\"fold\" id=\"todomvc\" open>").?;
    const notrun = std.mem.indexOf(u8, h, "<details class=\"fold\" id=\"not-run\">").?;
    const method = std.mem.indexOf(u8, h, "<details class=\"fold\" id=\"method\">").?;
    try testing.expect(chart < todo and todo < notrun and notrun < method);
    // Each chart row once, in order.
    var at: usize = 0;
    for ([_][]const u8{ "angular", "htmx", "jquery", "todomvc", "react", "svelte", "vue" }) |id| {
        const needle = try std.fmt.allocPrint(a, "<div class=\"dr\" role=\"listitem\" id=\"r-{s}\">", .{id});
        try testing.expectEqual(@as(usize, 1), occurrences(h, needle));
        const i = std.mem.indexOf(u8, h, needle).?;
        try testing.expect(i > at);
        at = i;
    }
    // The rates and counts, from the journals: Angular 997 / 1,000.
    try testing.expect(std.mem.indexOf(u8, h, "<div class=\"dr-v c\"><span class=\"vl\">Crane</span><span class=\"vh\">Crane: </span><b>99.7%</b><span>997 / 1,000</span></div><div class=\"dr-v g\"><span class=\"vl\">Chrome</span><span class=\"vh\">Chrome: </span><b>99.9%</b><span>1,099 / 1,100</span></div>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<title>Crane: 997 / 1,000 (99.7%)</title>") != null);
    try testing.expect(std.mem.indexOf(u8, h, "<span class=\"vh\">Chrome: </span>no run</div>") != null);
    // A framework that waits: hatched, its mark and its reason, once each.
    try testing.expectEqual(@as(usize, 3), occurrences(h, "<span class=\"mark-wait\">can&#39;t run yet &middot; waits for CDP</span>"));
    try testing.expectEqual(@as(usize, 3), occurrences(h, "<span class=\"why\">its test runner drives the browser over CDP, which Crane does not support yet (after 0.1)</span>"));
    // TodoMVC: apps passing everything, highest first.
    try testing.expect(std.mem.indexOf(u8, h, "<p class=\"allpass\"><b>1</b> of 3 apps pass every test in Crane, <b>1</b> in Chrome.</p>") != null);
    const react_i = std.mem.indexOf(u8, h, "<span class=\"app-name\">React</span>").?;
    const gwt_i = std.mem.indexOf(u8, h, "<span class=\"app-name\">GWT</span>").?;
    const jq_i = std.mem.indexOf(u8, h, "<span class=\"app-name\">jQuery</span>").?;
    try testing.expect(react_i < gwt_i and gwt_i < jq_i);
    try testing.expect(std.mem.indexOf(u8, h, "soma.js is listed on todomvc.com but cannot be served") != null);
    // The axis note, once; the five-app folder decision, once.
    try testing.expectEqual(@as(usize, 1), occurrences(h, "class=\"axis-note\""));
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
