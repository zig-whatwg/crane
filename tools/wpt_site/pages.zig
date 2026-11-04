//! The site's pages, written as finished HTML: every number, name and message
//! is in the markup, and no page needs script for any of its content. Each
//! page loads one deferred script, site.js, which enhances what is already
//! there - the interactive history chart, sorting and filtering the tables,
//! the search, the subtest filters - and reads everything it shows from the
//! markup (and the search from paths.json).
//!
//!     index.html                     the record: headline numbers, scope,
//!                                    contents, one section per suite,
//!                                    revision history
//!     <dir>/index.html               one page per directory of the tree
//!     <dir>/<file>/index.html        one page per test file, its subtests
//!
//! So a directory is at `/crane/dom/nodes/` and a test file at
//! `/crane/dom/nodes/Node-cloneNode.html/` - the WPT path, as wpt.fyi names
//! it. Links are relative, so the site works from any base.
//!
//! Determinism: only index.html carries anything that changes from one
//! regeneration to the next without the results changing (the generation,
//! its date, the history). Directory and file pages depend on their own
//! results, the worklist and the WPT revision only, so an unchanged file
//! writes an unchanged page and the gh-pages history stays small.

const std = @import("std");
const model = @import("model.zig");
const html = @import("html.zig");
const chart = @import("chart.zig");
const reference_mod = @import("reference.zig");
const Io = std.Io;
const W = *Io.Writer;
const Error = Io.Writer.Error;

pub const Generation = chart.Generation;

pub const Revision = struct {
    sha: []const u8 = "",
    /// "upstream": the upstream WPT commit the fork's snapshot is based on
    /// (tests/wpt/.crane-upstream-revision); "fork": the fork's own commit,
    /// when no upstream revision is recorded; "unknown": neither.
    kind: []const u8 = "unknown",
};

pub const links = struct {
    pub const crane = "https://github.com/zig-whatwg/crane";
    pub const wpt_fork = "https://github.com/zig-whatwg/wpt";
    pub const wpt_upstream = "https://github.com/web-platform-tests/wpt";
    pub const wpt_docs = "https://web-platform-tests.org/";
};

pub const FileView = struct {
    path: []const u8,
    /// The runner's status for the file; null: not run.
    status: ?[]const u8,
    counts: model.Counts,
    message: ?[]const u8,
    gate: model.Gate,
    /// The run its record came from.
    run: ?[]const u8,
    has_detail: bool,
    /// Its entry in tools/wpt_gate_exemptions.txt, when it has one.
    exemption: ?*const model.Exemption = null,
    /// The reference run's result for the file (`Site.reference`), when it has one.
    ref: ?RefView = null,
};

/// A reference run's result for one file: never Crane's, shown beside it.
pub const RefView = struct {
    status: []const u8,
    counts: model.Counts,
    /// Under the same gate rule as Crane's, exemptions included.
    gate: model.Gate,
    urls: u64 = 0,
    /// Test URLs of the file the reference run has no result for.
    missing_urls: u64 = 0,
};

pub const DirView = struct {
    /// "dom/nodes/"; "" is the root.
    path: []const u8,
    totals: model.Totals = .{},
    /// The reference run's totals over the same files (one it lacks is unrun).
    ref_totals: model.Totals = .{},
    /// Child directory paths, sorted.
    dirs: []const []const u8 = &.{},
    /// Indices into `Site.files`, sorted by path.
    files: []const usize = &.{},
};

pub const RunInfo = struct {
    id: []const u8,
    commit: ?[]const u8,
    /// ISO 8601 UTC, from the journal's mtime.
    date: []const u8,
    journal: []const u8,
    files: u64 = 0,
};

pub const Site = struct {
    files: []const FileView,
    dirs: *const std.StringArrayHashMapUnmanaged(DirView),
    /// Top-level directory paths ("console/", "dom/", ...), sorted.
    suites: []const []const u8,
    runs: *const std.StringArrayHashMapUnmanaged(RunInfo),
    history: []const Generation,
    wpt: Revision,
    worklist_name: []const u8,
    detail_files: usize,
    /// Absolute URL of the published site, with a trailing slash.
    site_url: []const u8,
    /// The social card's path under the site, with its cache-busting query.
    card_ref: []const u8,
    /// tools/wpt_gate_exemptions.txt's entries, in the file's order.
    exemptions: []const model.Exemption = &.{},
    /// Another engine's run on the same worklist (reference.zig), shown beside
    /// Crane's and never counted as Crane's; null: no comparison.
    reference: ?*const reference_mod.Reference = null,
    /// Both engines' totals over the files both have a result for, and how many.
    both_crane: model.Totals = .{},
    both_ref: model.Totals = .{},
    both: usize = 0,
    /// Indices into `files`: both ran and the reference passes more subtests
    /// (most first); both ran and Crane passes more; only the reference ran;
    /// only Crane did.
    ahead_ref: []const usize = &.{},
    ahead_crane: []const usize = &.{},
    only_ref: []const usize = &.{},
    only_crane: []const usize = &.{},

    pub fn root(s: *const Site) *const DirView {
        return s.dirs.getPtr("").?;
    }

    pub fn dir(s: *const Site, p: []const u8) *const DirView {
        return s.dirs.getPtr(p).?;
    }

    /// 1-based section number of a suite ("dom/").
    pub fn suiteNo(s: *const Site, suite: []const u8) ?usize {
        for (s.suites, 1..) |x, i| if (std.mem.eql(u8, x, suite)) return i;
        return null;
    }

    pub fn latest(s: *const Site) Generation {
        return if (s.history.len > 0) s.history[s.history.len - 1] else .{};
    }
};

/// One test URL's result from the wptreport stream (a file may have several:
/// each global and each variant is one WPT test).
pub const SubtestRun = struct {
    test_url: []const u8,
    status: []const u8,
    message: ?[]const u8,
    subtests: []const Subtest,
    total: u64,
    pass: u64,
    /// PASS subtests counted but not listed (past `model.detail_limit`).
    passing_omitted: u64,
};

pub const Subtest = struct {
    name: []const u8,
    status: []const u8,
    message: ?[]const u8,
};

// ============================================================================
// Words
// ============================================================================

/// A file's standing as the site labels it: plain labels for the four
/// non-blocking standings, the runner's own word for a blocking one.
pub fn gateLabel(g: model.Gate) []const u8 {
    return switch (g) {
        .clean => "Clean",
        .partial => "With failures",
        .empty => "No subtests",
        .unrun => "Not run",
        .none_passed => "NONE-PASSED",
        .timeout => "TIMEOUT",
        .err => "ERROR",
        .crash => "CRASH",
        .exempt => "Exempt",
    };
}

fn markWord(status: []const u8) []const u8 {
    if (std.mem.eql(u8, status, "NOTRUN")) return "NOT RUN";
    if (std.mem.eql(u8, status, "PRECONDITION_FAILED")) return "PRECOND.";
    return status;
}

fn markClass(status: []const u8) []const u8 {
    if (std.mem.eql(u8, status, "PASS")) return "s-pass";
    if (std.mem.eql(u8, status, "FAIL")) return "s-fail";
    if (std.mem.eql(u8, status, "TIMEOUT")) return "s-timeout";
    if (std.mem.eql(u8, status, "NOTRUN")) return "s-notrun";
    return "s-other";
}

const reserved_ids = [_][]const u8{ "status", "exempt", "versus", "contents", "history", "main", "toc", "gens", "chart", "hl-label", "toc-title" };

/// The index section id of a suite ("dom/" -> "dom"), `suite-` prefixed
/// when it would collide with one of the page's own ids.
fn writeSectionId(w: W, suite: []const u8) Error!void {
    const name = suite[0 .. suite.len - 1];
    for (reserved_ids) |r| if (std.mem.eql(u8, r, name)) try w.writeAll("suite-");
    try html.href(w, name);
}

fn gateSpan(w: W, g: model.Gate) Error!void {
    try w.print("<span class=\"gate gate-{s}{s}\">{s}</span>", .{ g.word(), if (g.blocking()) " g-block" else "", gateLabel(g) });
}

fn commitLink(w: W, sha: ?[]const u8) Error!void {
    const s = sha orelse return w.writeAll("<span class=\"quiet\">commit not recorded</span>");
    if (s.len == 0 or std.mem.eql(u8, s, "?")) return w.writeAll("<span class=\"quiet\">commit not recorded</span>");
    try w.writeAll("<a href=\"" ++ links.crane ++ "/commit/");
    try html.href(w, s);
    try w.writeAll("\"><code>");
    try html.text(w, s);
    try w.writeAll("</code></a>");
}

/// A generation's range of commits, linked to GitHub's comparison of the two.
fn rangeLink(w: W, since: []const u8, head: []const u8) Error!void {
    try w.writeAll("<a href=\"" ++ links.crane ++ "/compare/");
    try html.href(w, since);
    try w.writeAll("...");
    try html.href(w, head);
    try w.writeAll("\"><code>");
    try html.text(w, since);
    try w.writeAll("</code>&hellip;<code>");
    try html.text(w, head);
    try w.writeAll("</code></a>");
}

/// The branches merged in a generation's range: `<code>a</code>, <code>b</code>`,
/// or with " and " before the last when `prose`.
fn landedList(w: W, landed: []const []const u8, prose: bool) Error!void {
    for (landed, 0..) |name, i| {
        if (i > 0) try w.writeAll(if (prose and i == landed.len - 1) (if (landed.len > 2) ", and " else " and ") else ", ");
        try w.writeAll("<code>");
        try html.text(w, name);
        try w.writeAll("</code>");
    }
}

fn sourceUrl(w: W, site: *const Site, p: []const u8) Error!void {
    if (std.mem.eql(u8, site.wpt.kind, "upstream")) {
        try w.writeAll(links.wpt_upstream ++ "/blob/");
        try html.href(w, site.wpt.sha);
    } else if (std.mem.eql(u8, site.wpt.kind, "fork")) {
        try w.writeAll(links.wpt_fork ++ "/blob/");
        try html.href(w, site.wpt.sha);
    } else {
        try w.writeAll(links.wpt_fork ++ "/blob/HEAD");
    }
    try w.writeByte('/');
    try html.href(w, p);
}

// ============================================================================
// The frame every page shares
// ============================================================================

/// Written at the start of index.html's body: the design direction this
/// build answers to (see DESIGN.md).
pub const direction_contract =
    \\<!--
    \\THESIS: Crane's WPT results read as a living standard - the WPT subtest numbers first, then a numbered section per suite with its own numbers, conformance box and tests table - refusing the CI dashboard's stat cards and headline percentage.
    \\OWN-WORLD: spec-paper white, near-black ink, link blue, conformance green, red for failure, grey for blocking, pale amber notes; book serif prose, workhorse sans data, monospace paths; hairline rules, numbered margins.
    \\STORY: An evaluator reads the subtest totals, then "Status of this document" (testharness only, headless), scans the numbered contents, opens a suite, a directory, a file, and reads its subtests.
    \\FIRST VIEWPORT: the title and the WPT subtest numbers in large type, the run's identity beneath them, the numbered contents rail at left.
    \\FORM: Living Standard, #1 on my list; seed a0daf20c. Written as finished HTML by the generator: every page's content is in its markup; site.js enhances it.
    \\FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
    \\-->
    \\
;

const Head = struct {
    /// Relative prefix from the page to the site root: "", "../", ...
    root: []const u8,
    title: []const u8,
    description: []const u8,
};

fn writeHead(w: W, h: Head) Error!void {
    try w.writeAll(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>
    );
    try html.text(w, h.title);
    try w.writeAll("</title>\n<meta name=\"description\" content=\"");
    try html.text(w, h.description);
    try w.writeAll(
        \\">
        \\<meta name="color-scheme" content="light dark">
        \\<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
        \\<meta name="theme-color" content="#15171a" media="(prefers-color-scheme: dark)">
        \\
    );
    try w.print("<link rel=\"preload\" href=\"{s}fonts/source-serif-4-latin.woff2\" as=\"font\" type=\"font/woff2\" crossorigin>\n", .{h.root});
    try w.print("<link rel=\"preload\" href=\"{s}fonts/public-sans-latin.woff2\" as=\"font\" type=\"font/woff2\" crossorigin>\n", .{h.root});
    try w.print("<link rel=\"stylesheet\" href=\"{s}site.css\">\n<link rel=\"icon\" href=\"data:,\">\n", .{h.root});
    try w.print("<script src=\"{s}site.js\" defer></script>\n", .{h.root});
}

fn writeFooter(w: W) Error!void {
    try w.writeAll(
        \\<footer class="foot">
        \\<p>Written as HTML by <code>tools/wpt_site/generate.zig</code> from the runner&rsquo;s journals and result streams; <code>site.js</code> adds the interactive chart, sorting, filtering and search. Faces: Source Serif 4, Public Sans and Source Code Pro, under the SIL Open Font License. <a href="
    ++ links.crane ++
        \\">Crane on GitHub</a>.</p>
        \\</footer>
        \\
    );
}

/// The contents rail: the document's sections, with each suite's file count.
/// It is on every page, so it carries nothing that changes with results.
fn writeRail(w: W, site: *const Site, root: []const u8, current: ?[]const u8) Error!void {
    const home = if (root.len == 0) "./" else root;
    try w.writeAll("<nav class=\"toc\" aria-labelledby=\"toc-title\">\n<p class=\"toc-title\" id=\"toc-title\">Contents</p>\n<ol class=\"toc-list\">\n");
    try w.print("<li class=\"toc-front\"><a href=\"{s}\"><span class=\"secno\"></span><span class=\"toc-name\">Subtest totals</span></a></li>\n", .{home});
    try w.print("<li class=\"toc-front\"><a href=\"{s}#status\"><span class=\"secno\"></span><span class=\"toc-name\">Status of this document</span></a></li>\n", .{root});
    // The comparison page: named by its engine alone, so no result or version
    // reaches the frame every page carries.
    if (site.reference) |r| try w.print("<li class=\"toc-front\"><a href=\"{s}{s}.html\"><span class=\"secno\"></span><span class=\"toc-name\">Crane and {s}</span></a></li>\n", .{ root, r.engine, r.label() });
    for (site.suites, 1..) |s, i| {
        const t = site.dir(s).totals;
        const here = if (current) |c| std.mem.eql(u8, c, s) else false;
        try w.print("<li class=\"toc-suite\"><a href=\"{s}", .{root});
        try html.href(w, s);
        try w.print("\"{s}><span class=\"secno\">{d}</span><span class=\"toc-name\">", .{ if (here) " aria-current=\"page\"" else "", i });
        try html.text(w, s);
        try w.writeAll("</span><span class=\"toc-count\" title=\"");
        try html.plural(w, t.files, "test file", "test files");
        try w.writeAll("\">");
        try html.num(w, t.files);
        try w.writeAll("</span></a></li>\n");
    }
    try w.print("<li class=\"toc-back\"><a href=\"{s}#history\"><span class=\"secno\">{d}</span><span class=\"toc-name\">Revision history</span></a></li>\n", .{ root, site.suites.len + 1 });
    try w.writeAll("</ol>\n</nav>\n");
}

fn writeClose(w: W, site: *const Site, root: []const u8, current: ?[]const u8) Error!void {
    try writeFooter(w);
    try w.writeAll("</main>\n");
    try writeRail(w, site, root, current);
    try w.writeAll("</div>\n</body>\n</html>\n");
}

/// "../../" for a page whose own directory is `depth` levels below the root.
fn rootFor(buf: []u8, depth: usize) []const u8 {
    var n: usize = 0;
    for (0..depth) |_| {
        @memcpy(buf[n..][0..3], "../");
        n += 3;
    }
    return buf[0..n];
}

fn depthOf(p: []const u8) usize {
    return std.mem.count(u8, p, "/");
}

/// Breadcrumb from the site root down to `p` (a directory path, or a file
/// path when `is_file`).
fn writeCrumbs(w: W, root: []const u8, p: []const u8, is_file: bool) Error!void {
    try w.writeAll("<nav class=\"crumbs\" aria-label=\"Breadcrumb\"><ol>");
    try w.print("<li><a href=\"{s}\">Crane WPT results</a></li>", .{root});
    const segs_end = if (is_file) p.len else p.len - 1;
    var it = std.mem.splitScalar(u8, p[0..segs_end], '/');
    var consumed: usize = 0;
    while (it.next()) |seg| {
        consumed += seg.len + 1;
        const last = consumed >= segs_end;
        if (last) {
            try w.writeAll("<li aria-current=\"page\">");
            try html.path(w, if (is_file) seg else p[consumed - seg.len - 1 .. consumed]);
            try w.writeAll("</li>");
        } else {
            try w.print("<li><a href=\"{s}", .{root});
            try html.href(w, p[0..consumed]);
            try w.writeAll("\">");
            try html.path(w, p[consumed - seg.len - 1 .. consumed]);
            try w.writeAll("</a></li>");
        }
    }
    try w.writeAll("</ol></nav>\n");
}

// ============================================================================
// Numbers
// ============================================================================

const Figures = struct {
    pass: u64,
    reported: u64,
    failed: u64,
    timed_out: u64,
    notrun: u64,
    files: ?u64 = null,
    blocking: ?u64 = null,
    /// The latest generation's flaky files (index only).
    flaky: ?u64 = null,
    /// Beside the flaky count: files retried, and skipped as unchanged.
    retried: ?u64 = null,
    retry_skipped: ?u64 = null,

    fn ofTotals(t: model.Totals) Figures {
        return .{ .pass = t.sub_pass, .reported = t.subReported(), .failed = t.sub_fail, .timed_out = t.sub_timeout, .notrun = t.sub_notrun, .files = t.files, .blocking = t.blocking() };
    }
};

fn writeCounts(w: W, cls: []const u8, f: Figures) Error!void {
    try w.print("<dl class=\"{s}\">", .{cls});
    // Red is failure, grey is blocking (the user, 2026-09-30).
    const rows = [_]struct { []const u8, ?u64, []const u8 }{
        .{ "Failed", f.failed, " class=\"fail\"" },
        .{ "Timed out", f.timed_out, "" },
        .{ "Not run", f.notrun, "" },
        .{ "Test files", f.files, "" },
        .{ "Blocking files", f.blocking, " class=\"blk\"" },
        .{ "Flaky files", f.flaky, "" },
        .{ "Files retried", f.retried, "" },
        .{ "Retry skipped (unchanged)", f.retry_skipped, "" },
    };
    for (rows) |r| {
        const v = r[1] orelse continue;
        try w.print("<div{s}><dt>{s}</dt><dd>", .{ if (v > 0) r[2] else "", r[0] });
        try html.num(w, v);
        try w.writeAll("</dd></div>");
    }
    try w.writeAll("</dl>\n");
}

/// The headline: passed / reported in large type, the rest beneath.
fn writeHeadline(w: W, f: Figures) Error!void {
    try w.writeAll("<div class=\"headline\" role=\"group\" aria-labelledby=\"hl-label\">\n<p class=\"headline-figure\"><span class=\"hl-pass\">");
    try html.num(w, f.pass);
    try w.writeAll("</span><span class=\"hl-of\"> / ");
    try html.num(w, f.reported);
    try w.writeAll("</span></p>\n<p class=\"headline-label\" id=\"hl-label\">WPT subtests passing</p>\n");
    try writeCounts(w, "headline-counts", f);
    try w.writeAll("</div>\n");
}

/// A suite's, directory's or file's own numbers, opening its section.
fn writeFigures(w: W, label: []const u8, f: Figures) Error!void {
    try w.writeAll("<div class=\"figures\" role=\"group\" aria-label=\"");
    try html.text(w, label);
    try w.writeAll("\">\n<p class=\"figures-main\"><span class=\"fg-pass\">");
    try html.num(w, f.pass);
    try w.writeAll("</span><span class=\"fg-of\"> / ");
    try html.num(w, f.reported);
    try w.writeAll("</span> <span class=\"fg-label\">WPT subtests passing</span></p>\n");
    try writeCounts(w, "figures-counts", f);
    try w.writeAll("</div>\n");
}

// ============================================================================
// Boxes and tables
// ============================================================================

const Seg = struct { class: []const u8, v: u64 };

fn segments(t: model.Totals) [6]Seg {
    return .{
        .{ .class = "m-clean", .v = t.clean },
        .{ .class = "m-partial", .v = t.partial },
        .{ .class = "m-empty", .v = t.empty },
        .{ .class = "m-exempt", .v = t.exempt },
        .{ .class = "m-blocking", .v = t.blocking() },
        .{ .class = "m-unrun", .v = t.unrun },
    };
}

fn writeMeterSegments(w: W, t: model.Totals) Error!void {
    if (t.files == 0) return;
    for (segments(t)) |s| {
        if (s.v == 0) continue;
        const pct = @as(f64, @floatFromInt(s.v)) * 100.0 / @as(f64, @floatFromInt(t.files));
        try w.print("<span class=\"{s}\" style=\"width:{d:.3}%\"></span>", .{ s.class, pct });
    }
}

fn writeStandingWords(w: W, t: model.Totals) Error!void {
    try html.num(w, t.clean);
    try w.writeAll(" clean, ");
    try html.num(w, t.partial);
    try w.writeAll(" with failures, ");
    try html.num(w, t.blocking());
    try w.writeAll(" blocking, ");
    try html.num(w, t.empty);
    try w.writeAll(" with no subtests, ");
    try html.num(w, t.unrun);
    try w.writeAll(" not run, ");
    if (t.exempt > 0) {
        try html.num(w, t.exempt);
        try w.writeAll(" exempt, ");
    }
    try w.writeAll("of ");
    try html.plural(w, t.files, "file", "files");
}

fn writeConformance(w: W, label: []const u8, t: model.Totals) Error!void {
    try w.writeAll("<aside class=\"box conf\" aria-label=\"Conformance of ");
    try html.text(w, label);
    try w.writeAll("\">\n<div class=\"box-head\"><h3 class=\"box-title\">Conformance</h3><span class=\"box-sub\">");
    try html.plural(w, t.files, "file", "files");
    try w.writeAll("</span></div>\n<div class=\"conf-body\">\n<div class=\"meter\" role=\"img\" aria-label=\"");
    try writeStandingWords(w, t);
    try w.writeAll("\">");
    try writeMeterSegments(w, t);
    try w.writeAll("</div>\n<dl>");
    const Row = struct { key: []const u8, label: []const u8, v: u64, always: bool };
    const rows = [_]Row{
        .{ .key = "clean", .label = "Clean", .v = t.clean, .always = true },
        .{ .key = "partial", .label = "With failures", .v = t.partial, .always = true },
        .{ .key = "blocking", .label = "Blocking", .v = t.blocking(), .always = true },
        .{ .key = "empty", .label = "No subtests", .v = t.empty, .always = false },
        .{ .key = "unrun", .label = "Not run", .v = t.unrun, .always = false },
        .{ .key = "exempt", .label = "Exempt", .v = t.exempt, .always = false },
    };
    for (rows) |r| {
        if (!r.always and r.v == 0) continue;
        const blk = std.mem.eql(u8, r.key, "blocking") and r.v > 0;
        try w.print("<div{s}><dt><span class=\"key key-{s}\"></span>{s}</dt><dd>", .{ if (blk) " class=\"blk\"" else "", r.key, r.label });
        try html.num(w, r.v);
        try w.writeAll("</dd></div>");
        if (blk) {
            try w.writeAll("<p class=\"kinds\">");
            const kinds = [_]struct { []const u8, u64 }{
                .{ "NONE-PASSED", t.none_passed }, .{ "TIMEOUT", t.timeout }, .{ "ERROR", t.err }, .{ "CRASH", t.crash },
            };
            var first = true;
            for (kinds) |k| {
                if (k[1] == 0) continue;
                if (!first) try w.writeAll(", ");
                first = false;
                try w.writeAll("<b>");
                try html.num(w, k[1]);
                try w.print("</b> {s}", .{k[0]});
            }
            try w.writeAll("</p>");
        }
    }
    try w.writeAll("</dl>\n</div>\n</aside>\n");
}

fn writeMini(w: W, t: model.Totals) Error!void {
    try w.writeAll("<span class=\"mini\" aria-hidden=\"true\">");
    try writeMeterSegments(w, t);
    try w.writeAll("</span>");
}

fn writePassOf(w: W, pass: u64, reported: u64) Error!void {
    if (reported == 0) return w.writeAll("<span class=\"quiet\">none reported</span>");
    try w.writeAll("<b>");
    try html.num(w, pass);
    try w.writeAll("</b> / ");
    try html.num(w, reported);
}

/// The reference run's column head in a tests table, when there is one.
fn writeRefHead(w: W, site: *const Site) Error!void {
    const r = site.reference orelse return;
    try w.print("<th scope=\"col\" class=\"n\">{s}</th>", .{r.label()});
}

/// The reference run's subtests passing in a table row; `ran` false: it has
/// no result there.
fn writeRefCell(w: W, pass: u64, reported: u64, ran: bool) Error!void {
    if (!ran) return w.writeAll("<td class=\"n\"><span class=\"quiet\">&mdash;</span></td>");
    try w.print("<td class=\"n\" data-v=\"{d}\" data-of=\"{d}\">", .{ pass, reported });
    try writePassOf(w, pass, reported);
    try w.writeAll("</td>");
}

/// Beneath a directory's or suite's figures: the reference run's numbers for
/// the same files.
fn writeRefFigures(w: W, site: *const Site, t: model.Totals) Error!void {
    const r = site.reference orelse return;
    try w.print("<p class=\"figures-ref\"><span class=\"ref-name\">{s}</span> ", .{r.label()});
    try writePassOf(w, t.sub_pass, t.subReported());
    try w.writeAll(" WPT subtests passing on the same files, ");
    if (t.blocking() > 0) {
        try w.writeAll("<span class=\"blk\">");
        try html.num(w, t.blocking());
        try w.writeAll(" blocking</span>");
    } else try w.writeAll("<span class=\"quiet\">none blocking</span>");
    if (t.unrun > 0) {
        try w.writeAll(", <span class=\"quiet\">");
        try html.num(w, t.unrun);
        try w.writeAll(" without a result</span>");
    }
    try w.writeAll("</p>\n");
}

/// The directories table. `base` is the href prefix from the page to the
/// site root; `number_under` numbers the rows N.i when the list is a suite's.
fn writeDirTable(w: W, site: *const Site, base: []const u8, dirs: []const []const u8, number_under: ?usize, row_ids: bool) Error!void {
    if (dirs.len == 0) return;
    try w.print("<table class=\"listing listing-dirs{s}\">\n<thead><tr><th scope=\"col\">Directory</th><th scope=\"col\" class=\"n\">Subtests passing</th>", .{if (site.reference != null) " has-ref" else ""});
    try writeRefHead(w, site);
    try w.writeAll("<th scope=\"col\" class=\"n\">Test files</th><th scope=\"col\">Standing</th></tr></thead>\n<tbody>\n");
    for (dirs, 1..) |d, i| {
        const t = site.dir(d).totals;
        try w.writeAll("<tr");
        if (row_ids) {
            try w.writeAll(" id=\"");
            try html.text(w, d);
            try w.writeAll("\"");
        }
        try w.print("><th scope=\"row\"><a href=\"{s}", .{base});
        try html.href(w, d);
        try w.writeAll("\">");
        if (number_under) |n| try w.print("<span class=\"dir-no\">{d}.{d}</span>", .{ n, i });
        const name_start = if (std.mem.lastIndexOfScalar(u8, d[0 .. d.len - 1], '/')) |k| k + 1 else 0;
        try html.path(w, d[name_start..]);
        try w.print("</a></th><td class=\"n\" data-v=\"{d}\" data-of=\"{d}\">", .{ t.sub_pass, t.subReported() });
        try writePassOf(w, t.sub_pass, t.subReported());
        try w.writeAll("</td>");
        if (site.reference != null) {
            const rt = site.dir(d).ref_totals;
            try writeRefCell(w, rt.sub_pass, rt.subReported(), rt.files > rt.unrun);
        }
        try w.print("<td class=\"n\" data-v=\"{d}\">", .{t.files});
        try html.num(w, t.files);
        try w.print("</td><td data-v=\"{d}\"><span class=\"tally\">", .{t.blocking()});
        if (t.blocking() > 0) {
            try w.writeAll("<span class=\"blk\">");
            try html.num(w, t.blocking());
            try w.writeAll(" blocking</span>");
        } else {
            try w.writeAll("<span class=\"quiet\">none blocking</span>");
        }
        try writeMini(w, t);
        try w.writeAll("</span></td></tr>\n");
    }
    try w.writeAll("</tbody>\n</table>\n");
}

fn writeFileTable(w: W, site: *const Site, base: []const u8, files: []const usize, row_ids: bool) Error!void {
    if (files.len == 0) return;
    try w.print("<table class=\"listing listing-files{s}\">\n<thead><tr><th scope=\"col\">Test file</th><th scope=\"col\" class=\"n\">Subtests passing</th>", .{if (site.reference != null) " has-ref" else ""});
    try writeRefHead(w, site);
    try w.writeAll("<th scope=\"col\" class=\"n\">Failed</th><th scope=\"col\">Standing</th></tr></thead>\n<tbody>\n");
    for (files) |fi| {
        const f = site.files[fi];
        try w.print("<tr data-gate=\"{s}\"", .{f.gate.word()});
        if (row_ids) {
            try w.writeAll(" id=\"");
            try html.text(w, f.path);
            try w.writeAll("\"");
        }
        try w.print("><th scope=\"row\"><a href=\"{s}", .{base});
        try html.href(w, f.path);
        try w.writeAll("/\">");
        try html.path(w, baseName(f.path));
        try w.print("</a></th><td class=\"n\" data-v=\"{d}\" data-of=\"{d}\">", .{ f.counts.passed, f.counts.reported() });
        if (f.status == null) {
            try w.writeAll("<span class=\"quiet\">&mdash;</span>");
        } else {
            try writePassOf(w, f.counts.passed, f.counts.reported());
        }
        try w.writeAll("</td>");
        if (site.reference != null) {
            if (f.ref) |rv| try writeRefCell(w, rv.counts.passed, rv.counts.reported(), true) else try writeRefCell(w, 0, 0, false);
        }
        try w.print("<td class=\"n\" data-v=\"{d}\">", .{f.counts.failed});
        if (f.counts.failed > 0) {
            try w.writeAll("<span class=\"fail\">");
            try html.num(w, f.counts.failed);
            try w.writeAll("</span>");
        } else try w.writeAll("<span class=\"quiet\">0</span>");
        try w.print("</td><td data-v=\"{d}\">", .{@backingInt(f.gate)});
        try gateSpan(w, f.gate);
        try w.writeAll("</td></tr>\n");
    }
    try w.writeAll("</tbody>\n</table>\n");
}

fn baseName(p: []const u8) []const u8 {
    const trimmed = if (std.mem.endsWith(u8, p, "/")) p[0 .. p.len - 1] else p;
    const i = std.mem.lastIndexOfScalar(u8, trimmed, '/') orelse return trimmed;
    return trimmed[i + 1 ..];
}

/// Above this many test files directly in a suite, the index names them in
/// one summary row and the suite's own page lists them.
pub const index_file_cap = 24;

// ============================================================================
// index.html
// ============================================================================

pub fn writeIndex(w: W, site: *const Site) Error!void {
    const tot = site.root().totals;
    const g = site.latest();
    var f = Figures.ofTotals(tot);
    f.flaky = g.flaky;
    f.retried = g.retried;
    f.retry_skipped = g.retry_skipped;

    try writeHead(w, .{ .root = "", .title = "Crane WPT Results", .description = "Crane's own web-platform-tests results: a headless web platform engine written in Zig, measured by its own runner. Testharness tests only; rendering and layout are out of scope by design." });
    try writeSocial(w, site, f);
    try w.writeAll("</head>\n<body>\n");
    try w.writeAll(direction_contract);
    try w.writeAll("<div class=\"frame\">\n<main class=\"doc\" id=\"main\">\n<header class=\"head\">\n<h1>Crane <span class=\"h1-rest\">Web Platform Tests Results</span></h1>\n");
    try writeHeadline(w, f);
    try w.writeAll("<p class=\"subtitle\">Crane&rsquo;s conformance record, regenerated with every run; last updated ");
    try html.longDate(w, g.at);
    try w.writeAll("</p>\n<dl class=\"head-meta\">\n<div><dt>This version</dt><dd>");
    try w.print("Generation {d}, recorded at Crane ", .{g.n});
    if (g.since.len > 0) {
        try rangeLink(w, g.since, g.head);
        if (g.commits == 0) {
            try w.print(": no new commits since generation {d}", .{g.since_n});
        } else {
            try w.print(": {d} commit{s} since generation {d}", .{ g.commits, if (g.commits == 1) "" else "s", g.since_n });
            if (g.landed.len > 0) {
                try w.writeAll(", merging ");
                try landedList(w, g.landed, true);
            }
        }
    } else try commitLink(w, g.head);
    try w.writeAll("</dd></div>\n<div><dt>Runs</dt><dd>");
    try writeRuns(w, site);
    try w.writeAll("</dd></div>\n<div><dt>WPT revision</dt><dd>");
    try writeRevision(w, site.wpt);
    try w.writeAll("</dd></div>\n<div class=\"head-history\"><dt>History</dt><dd><a class=\"spark-link\" href=\"#history\">");
    try chart.draw(w, site.history, .{ .width = 168, .height = 30, .spark = true, .class = "spark" });
    try w.writeAll("<span class=\"spark-text\">");
    try html.plural(w, site.history.len, "generation", "generations");
    if (site.history.len > 0) {
        try w.writeAll(" since <span class=\"nowrap\">");
        try html.shortDateY(w, site.history[0].at);
        try w.writeAll("</span>");
    }
    try w.writeAll("</span></a></dd></div>\n</dl>\n</header>\n");

    try writeStatus(w, site, tot);
    try writeExempt(w, site);
    try writeVersus(w, site);
    try writeContents(w, site);
    for (site.suites, 1..) |s, i| try writeSuite(w, site, s, i);
    try writeHistory(w, site, tot);
    try writeClose(w, site, "", null);
}

fn writeSocial(w: W, site: *const Site, f: Figures) Error!void {
    // Crawlers do not run script: the card's words and numbers are here.
    try w.writeAll("<link rel=\"canonical\" href=\"");
    try html.text(w, site.site_url);
    try w.writeAll("\">\n<meta property=\"og:type\" content=\"website\">\n<meta property=\"og:site_name\" content=\"Crane\">\n<meta property=\"og:title\" content=\"Crane WPT results: ");
    try html.num(w, f.pass);
    try w.writeAll(" / ");
    try html.num(w, f.reported);
    try w.writeAll(" WPT subtests passing\">\n<meta property=\"og:description\" content=\"");
    try writeSocialDescription(w, f);
    try w.writeAll("\">\n<meta property=\"og:url\" content=\"");
    try html.text(w, site.site_url);
    try w.writeAll("\">\n<meta property=\"og:image\" content=\"");
    try html.text(w, site.site_url);
    try html.text(w, site.card_ref);
    try w.writeAll("\">\n<meta property=\"og:image:type\" content=\"image/png\">\n<meta property=\"og:image:width\" content=\"1200\">\n<meta property=\"og:image:height\" content=\"630\">\n<meta property=\"og:image:alt\" content=\"");
    try html.num(w, f.pass);
    try w.writeAll(" of ");
    try html.num(w, f.reported);
    try w.writeAll(" WPT subtests passing in Crane.\">\n<meta name=\"twitter:card\" content=\"summary_large_image\">\n<meta name=\"twitter:title\" content=\"Crane WPT results: ");
    try html.num(w, f.pass);
    try w.writeAll(" / ");
    try html.num(w, f.reported);
    try w.writeAll(" WPT subtests passing\">\n<meta name=\"twitter:description\" content=\"");
    try writeSocialDescription(w, f);
    try w.writeAll("\">\n<meta name=\"twitter:image\" content=\"");
    try html.text(w, site.site_url);
    try html.text(w, site.card_ref);
    try w.writeAll("\">\n");
}

fn writeSocialDescription(w: W, f: Figures) Error!void {
    try html.num(w, f.failed);
    try w.writeAll(" failed, ");
    try html.num(w, f.timed_out);
    try w.writeAll(" timed out, ");
    try html.num(w, f.notrun);
    try w.writeAll(" not run; ");
    try html.num(w, f.files orelse 0);
    try w.writeAll(" test files, ");
    try html.num(w, f.blocking orelse 0);
    try w.writeAll(" blocking. Crane is a headless web platform engine in Zig; testharness tests only, rendering and layout out of scope.");
}

fn writeRuns(w: W, site: *const Site) Error!void {
    const keys = site.runs.keys();
    if (keys.len == 0) return w.writeAll("none yet");
    // The two runs that hold the most files, then how many more.
    var top: [2]?usize = .{ null, null };
    for (site.runs.values(), 0..) |r, i| {
        const better = struct {
            fn f(a: RunInfo, b: RunInfo) bool {
                return a.files > b.files or (a.files == b.files and std.mem.order(u8, a.id, b.id) == .lt);
            }
        }.f;
        if (top[0] == null or better(r, site.runs.values()[top[0].?])) {
            top[1] = top[0];
            top[0] = i;
        } else if (top[1] == null or better(r, site.runs.values()[top[1].?])) {
            top[1] = i;
        }
    }
    var shown: usize = 0;
    for (top) |ti| {
        const i = ti orelse continue;
        const r = site.runs.values()[i];
        if (shown > 0) try w.writeAll("; ");
        shown += 1;
        try w.writeAll("<code>");
        try html.text(w, r.id);
        try w.writeAll("</code> (");
        try html.plural(w, r.files, "file", "files");
        try w.writeAll(", ");
        if (r.commit) |c| try commitLink(w, c) else try w.writeAll("commit not in its label");
        try w.writeAll(", <span class=\"nowrap\">");
        try html.shortDateY(w, r.date);
        try w.writeAll("</span>)");
    }
    if (keys.len > shown) {
        try w.writeAll("<span class=\"quiet\">; and ");
        try html.plural(w, keys.len - shown, "more run", "more runs");
        try w.writeAll(", named on each file&rsquo;s page</span>");
    }
}

fn writeRevision(w: W, r: Revision) Error!void {
    const short = r.sha[0..@min(10, r.sha.len)];
    if (std.mem.eql(u8, r.kind, "upstream")) {
        try w.writeAll("<a href=\"" ++ links.wpt_upstream ++ "/tree/");
        try html.href(w, r.sha);
        try w.writeAll("\"><code>");
        try html.text(w, short);
        try w.writeAll("</code></a> upstream, the commit Crane&rsquo;s snapshot is based on");
    } else if (std.mem.eql(u8, r.kind, "fork")) {
        try w.writeAll("<a href=\"" ++ links.wpt_fork ++ "/tree/");
        try html.href(w, r.sha);
        try w.writeAll("\"><code>");
        try html.text(w, short);
        try w.writeAll("</code></a> in Crane&rsquo;s fork of WPT (the upstream revision it tracks is not recorded)");
    } else {
        try w.writeAll("not recorded for this generation");
    }
}

fn writeStatus(w: W, site: *const Site, tot: model.Totals) Error!void {
    try w.writeAll("<section class=\"front\" id=\"status\" aria-labelledby=\"status-h\">\n<h2 id=\"status-h\">Status of this document</h2>\n<div class=\"front-prose\">\n<p>Crane is a web platform engine written in Zig: the browser, minus the pixels. This is its record of its own results on the <a href=\"" ++ links.wpt_docs ++ "\">web-platform-tests</a> (WPT), measured by its own runner and regenerated with every run. <strong>Scope:</strong> the ");
    try html.num(w, tot.files);
    try w.writeAll(" testharness files of the 0.1 worklist, in ");
    try html.plural(w, site.suites.len, "suite", "suites");
    try w.writeAll(". Reftests and tests that need rendering or layout (<code>html/rendering/</code>, <code>canvas</code>, scrolling, focus traversal) are out of scope by design, and every total describes this scope and nothing wider.</p>\n<p><strong>About the totals.</strong> Crane passes ");
    try html.num(w, tot.sub_pass);
    try w.writeAll(" of the ");
    try html.num(w, tot.subReported());
    try w.writeAll(" subtests its runs reported.");
    if (site.reference) |r| {
        try w.print(" {s}&rsquo;s results on the same files are in <a href=\"#versus\">Crane and {s}</a>, beside Crane&rsquo;s and never counted in them", .{ r.label(), r.label() });
    } else try w.writeAll(" This is not a browser comparison");
    if (site.dirs.getPtr("encoding/")) |enc| {
        const et = enc.totals;
        if (tot.subReported() > 0 and et.subReported() > 0) {
            const share = (et.subReported() * 100 + tot.subReported() / 2) / tot.subReported();
            try w.print(", and the subtest total mostly measures <code>encoding/</code>, which holds {d}% of all reported subtests (", .{share});
            try html.num(w, et.subReported());
            try w.writeAll(" of ");
            try html.num(w, tot.subReported());
            try w.writeAll(") in ");
            try html.plural(w, et.files, "file", "files");
        }
    }
    try w.writeAll(". A file <strong>blocks</strong> the 0.1 gate when it times out, errors, crashes or finishes with no subtest passing (<span class=\"st st-issue\">TIMEOUT</span>, <span class=\"st st-issue\">ERROR</span>, <span class=\"st st-issue\">CRASH</span>, <span class=\"st st-issue\">NONE-PASSED</span>): ");
    try html.plural(w, tot.blocking(), "file blocks", "files block");
    try w.writeAll(" today.");
    if (site.exemptions.len > 0) {
        try w.writeAll(" Not counted among them: ");
        try html.plural(w, tot.exempt, "file that would block is", "files that would block are");
        try w.writeAll(" <a href=\"#exempt\">exempt</a>, because all three of Chrome, Firefox and Safari intentionally deviate from the spec they test.");
    }
    try w.writeAll(" Per-subtest detail comes from the runner&rsquo;s result streams: ");
    if (site.detail_files > 0) {
        try html.num(w, site.detail_files);
        try w.writeAll(" of ");
        try html.num(w, tot.files);
        try w.writeAll(" files have it in this generation.");
    } else {
        try w.writeAll("no file has it in this generation yet, so each file&rsquo;s page gives its counts.");
    }
    try w.writeAll("</p>\n</div>\n<div class=\"note\" role=\"note\">\n<p class=\"note-label\">How to read a section</p>\n<p>Each suite is a numbered section that opens with its own subtest numbers. Its <em>Conformance</em> box counts files by standing; its <em>Tests</em> tables link to a page for every directory and every test file, and a test file&rsquo;s page lists its subtests. Everything has a permanent link, <span class=\"self-demo\" aria-hidden=\"true\">&para;</span>.</p>\n<dl class=\"legend\" aria-label=\"File standings\">\n<div><dt><span class=\"key key-clean\"></span>Clean</dt><dd>every reported subtest passed</dd></div>\n<div><dt><span class=\"key key-partial\"></span>With failures</dt><dd>some subtests passed, some did not</dd></div>\n<div><dt><span class=\"key key-blocking\"></span>Blocking</dt><dd>NONE-PASSED, TIMEOUT, ERROR, CRASH</dd></div>\n<div><dt><span class=\"key key-empty\"></span>No subtests</dt><dd>the file ran and reported none</dd></div>\n<div><dt><span class=\"key key-unrun\"></span>Not run</dt><dd>no result yet</dd></div>\n");
    if (site.exemptions.len > 0) try w.writeAll("<div><dt><span class=\"key key-exempt\"></span>Exempt</dt><dd>would block, but all three browsers intentionally deviate from the spec it tests</dd></div>\n");
    try w.writeAll("</dl>\n</div>\n</section>\n");
}

/// One exemption's evidence: what the browsers do instead, the spec, and
/// each browser's wpt.fyi result and evidence of intent.
fn writeEvidence(w: W, e: *const model.Exemption) Error!void {
    try w.writeAll("<p>");
    try html.text(w, e.why);
    try w.writeAll("</p>\n<dl class=\"evidence\"><div><dt>Spec</dt><dd><a href=\"");
    try html.text(w, e.spec);
    try w.writeAll("\">");
    try html.text(w, e.spec);
    try w.writeAll("</a></dd></div>");
    inline for (comptime std.enums.values(model.Browser)) |b| {
        const i = @backingInt(b);
        try w.print("<div><dt>{s}</dt><dd>", .{b.label()});
        try html.text(w, e.result[i]);
        try w.writeAll("; intent: <a href=\"");
        try html.text(w, e.intent[i]);
        try w.writeAll("\">");
        try html.text(w, e.intent[i]);
        try w.writeAll("</a></dd></div>");
    }
    try w.writeAll("</dl>\n");
}

/// The exempt group: every file tools/wpt_gate_exemptions.txt lists, with its
/// evidence. Written only when the file lists one, so an empty list changes
/// no byte of the page.
fn writeExempt(w: W, site: *const Site) Error!void {
    if (site.exemptions.len == 0) return;
    try w.writeAll("<section class=\"front\" id=\"exempt\" aria-labelledby=\"exempt-h\">\n<h2 id=\"exempt-h\">Exempt from the gate</h2>\n<div class=\"front-prose\">\n<p>These files are omitted from the blocking count: all three of Chrome, Firefox and Safari intentionally deviate from the spec each tests, each with evidence of intent (a standards position, a WontFix bug or an implementer&rsquo;s objection), and Crane does as they do. A listed file that does not block keeps its own standing.</p>\n<ol class=\"exempt-list\">\n");
    for (site.exemptions) |*e| {
        try w.writeAll("<li><a href=\"");
        try html.href(w, e.path);
        try w.writeAll("/\"><code>");
        try html.text(w, e.path);
        try w.writeAll("</code></a> ");
        for (site.files) |f| if (std.mem.eql(u8, f.path, e.path)) try gateSpan(w, f.gate);
        try w.writeAll("\n");
        try writeEvidence(w, e);
        try w.writeAll("</li>\n");
    }
    try w.writeAll("</ol>\n</div>\n</section>\n");
}

fn writeContents(w: W, site: *const Site) Error!void {
    try w.writeAll("<section class=\"contents\" id=\"contents\" aria-labelledby=\"contents-h\">\n<h2 id=\"contents-h\">Contents</h2>\n<ol class=\"contents-list\">\n");
    for (site.suites, 1..) |s, i| {
        const t = site.dir(s).totals;
        try w.print("<li><a href=\"#", .{});
        try writeSectionId(w, s);
        try w.print("\"><span class=\"secno\">{d}</span>", .{i});
        try html.path(w, s);
        try w.writeAll("</a><span class=\"cl-figs\">");
        try writePassOf(w, t.sub_pass, t.subReported());
        try w.writeAll(" <span class=\"quiet\">subtests</span></span><span class=\"cl-files\">");
        try html.plural(w, t.files, "file", "files");
        try w.writeAll("</span><span class=\"cl-blk\">");
        if (t.blocking() > 0) {
            try w.writeAll("<span class=\"blk\">");
            try html.num(w, t.blocking());
            try w.writeAll(" blocking</span>");
        }
        try w.writeAll("</span></li>\n");
    }
    try w.print("<li class=\"cl-back\"><a href=\"#history\"><span class=\"secno\">{d}</span>Revision history</a></li>\n", .{site.suites.len + 1});
    try w.writeAll("</ol>\n</section>\n");
}

fn writeSuite(w: W, site: *const Site, s: []const u8, no: usize) Error!void {
    const d = site.dir(s);
    const t = d.totals;
    try w.writeAll("<section class=\"suite\" id=\"");
    try writeSectionId(w, s);
    try w.writeAll("\" aria-labelledby=\"");
    try writeSectionId(w, s);
    try w.print("-h\">\n<h2 id=\"", .{});
    try writeSectionId(w, s);
    try w.print("-h\"><span class=\"secno\">{d}</span><a class=\"h-link\" href=\"", .{no});
    try html.href(w, s);
    try w.writeAll("\">");
    try html.path(w, s);
    try w.writeAll("</a><a class=\"self\" href=\"#");
    try writeSectionId(w, s);
    try w.print("\" aria-label=\"Link to section {d}\">&para;</a></h2>\n", .{no});
    try writeFigures(w, s, Figures.ofTotals(t));
    try writeRefFigures(w, site, d.ref_totals);
    try w.writeAll("<div class=\"boxes\">\n");
    try writeConformance(w, s, t);
    try w.writeAll("<div class=\"box tests\">\n<div class=\"box-head\"><h3 class=\"box-title\">Tests</h3><a class=\"box-sub\" href=\"");
    try html.href(w, s);
    try w.writeAll("\">The ");
    try html.path(w, s);
    try w.writeAll(" page</a></div>\n");
    try writeDirTable(w, site, "", d.dirs, no, true);
    if (d.files.len > index_file_cap) {
        var ft: model.Totals = .{};
        for (d.files) |fi| ft.add(site.files[fi].gate, site.files[fi].counts);
        try w.writeAll("<p class=\"more-files\"><a href=\"");
        try html.href(w, s);
        try w.writeAll("\">");
        try html.plural(w, d.files.len, "test file", "test files");
        try w.writeAll(" directly in ");
        try html.path(w, s);
        try w.writeAll("</a>: ");
        try writePassOf(w, ft.sub_pass, ft.subReported());
        try w.writeAll(" subtests passing");
        if (ft.blocking() > 0) {
            try w.writeAll(", <span class=\"blk\">");
            try html.num(w, ft.blocking());
            try w.writeAll(" blocking</span>");
        }
        try w.writeAll(". They are listed on the suite&rsquo;s page.</p>\n");
    } else {
        try writeFileTable(w, site, "", d.files, true);
    }
    try w.writeAll("</div>\n</div>\n</section>\n");
}

fn writeHistory(w: W, site: *const Site, tot: model.Totals) Error!void {
    const gens = site.history;
    try w.print("<section class=\"back\" id=\"history\" aria-labelledby=\"history-h\">\n<h2 id=\"history-h\"><span class=\"secno\">{d}</span>Revision history<a class=\"self\" href=\"#history\" aria-label=\"Link to the revision history\">&para;</a></h2>\n", .{site.suites.len + 1});
    try w.writeAll("<p>One generation is recorded each time the progress report is regenerated and its results have moved. The chart shows WPT subtests passing in every generation, and those not passing up to the total, oldest at the left; the table below it holds every generation&rsquo;s numbers.</p>\n<figure class=\"chart\" id=\"chart\">\n");
    try chart.draw(w, gens, .{ .width = 960, .height = 320, .class = "chart-svg chart-wide" });
    try chart.draw(w, gens, .{ .width = 480, .height = 280, .class = "chart-svg chart-narrow" });
    try w.writeAll("\n<figcaption class=\"chart-key\"><span><span class=\"key key-pass\"></span>Subtests passing</span><span><span class=\"key key-fail\"></span>Not passing</span><span><span class=\"key key-total\"></span>Total subtests</span></figcaption>\n</figure>\n");

    // The note on how the history was measured, with its generation numbers.
    var first_live: ?usize = null;
    var first_exact: ?Generation = null;
    for (gens, 0..) |g, i| {
        if (first_live == null and !g.reconstructed) first_live = i;
        if (first_exact == null and !g.estimated()) first_exact = g;
    }
    try w.writeAll("<div class=\"note\" role=\"note\">\n<p class=\"note-label\">How this history was measured</p>\n<p>");
    if (first_live) |fl| {
        if (fl > 0) try w.print("Generations 1 to {d} were reconstructed afterwards from the journals that survived, so they show less than was measured at the time. ", .{gens[fl - 1].n});
    }
    var marked = false;
    for (gens) |g| {
        const label = chart.eventAt(&chart.events, g.n) orelse continue;
        if (!marked) try w.writeAll("The dashed lines mark changes of measurement: ");
        if (marked) try w.writeAll("; ");
        marked = true;
        try w.print("generation {d}, {s}", .{ g.n, label });
    }
    if (marked) try w.writeAll(". A jump at one of them is a change in what was counted as much as in Crane. ");
    if (first_exact) |g| {
        if (g.n > 1) try w.print("Before generation {d}, a generation&rsquo;s total is the progress report&rsquo;s count of subtests known to exist, which estimates the files that reported none; from it on, the total is the sum of every file&rsquo;s reported subtests, as the headline counts them.", .{g.n});
    } else if (gens.len > 0) {
        try w.writeAll("Each total is the progress report&rsquo;s count of subtests known to exist, which estimates the files that reported none.");
    }
    const last = site.latest();
    if (gens.len > 0 and (last.passing() != tot.sub_pass or last.subTotal() != tot.subReported())) {
        try w.print(" The latest generation, {d}, recorded ", .{last.n});
        try html.num(w, last.passing());
        try w.writeAll(" of ");
        try html.num(w, last.subTotal());
        try w.writeAll(" subtests passing; the headline reads the current results, ");
        try html.num(w, tot.sub_pass);
        try w.writeAll(" of ");
        try html.num(w, tot.subReported());
        try w.writeAll(", and the two agree again when the progress report next records a generation.");
    }
    try w.writeAll("</p>\n</div>\n");

    try w.writeAll("<details class=\"gens\" id=\"gens\">\n<summary><svg class=\"twisty\" viewBox=\"0 0 16 16\" aria-hidden=\"true\"><path d=\"M6 3.5 10.5 8 6 12.5\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>Every generation, newest first</summary>\n<div class=\"table-wrap\">\n<table>\n<thead><tr>");
    for ([_][]const u8{ "Gen.", "Date", "Crane", "Subtests passing", "Total subtests", "Not passing", "Blocking files", "Flaky files" }) |h| {
        try w.print("<th scope=\"col\">{s}</th>", .{h});
    }
    try w.writeAll("</tr></thead>\n<tbody>\n");
    var i = gens.len;
    while (i > 0) {
        i -= 1;
        try writeGenRow(w, gens[i]);
    }
    try w.writeAll("</tbody>\n</table>\n</div>\n</details>\n</section>\n");
}

/// One generation's row. Its data attributes are what site.js charts: the
/// cells say the same in words.
fn writeGenRow(w: W, g: Generation) Error!void {
    const known_head = g.head.len > 0 and !std.mem.eql(u8, g.head, "?");
    try w.print("<tr{s} data-n=\"{d}\" data-at=\"", .{ if (g.reconstructed) " class=\"recon\"" else "", g.n });
    try html.text(w, g.at);
    try w.writeAll("\"");
    if (known_head) {
        try w.writeAll(" data-head=\"");
        try html.text(w, g.head);
        try w.writeAll("\"");
    }
    if (g.since.len > 0) {
        try w.writeAll(" data-since=\"");
        try html.text(w, g.since);
        try w.print("\" data-commits=\"{d}\"", .{g.commits});
        if (g.landed.len > 0) {
            try w.writeAll(" data-landed=\"");
            for (g.landed, 0..) |name, i| {
                if (i > 0) try w.writeByte(' ');
                try html.text(w, name);
            }
            try w.writeAll("\"");
        }
    }
    try w.print(" data-pass=\"{d}\" data-total=\"{d}\"", .{ g.passing(), g.subTotal() });
    if (g.subs) |sb| {
        try w.print(" data-fail=\"{d}\" data-timeout=\"{d}\" data-notrun=\"{d}\"", .{ sb.failed, sb.timed_out, sb.notrun });
    } else try w.writeAll(" data-est=\"1\"");
    try w.print(" data-blocking=\"{d}\" data-files=\"{d}\"", .{ g.blocking, g.total });
    if (g.flaky) |n| try w.print(" data-flaky=\"{d}\"", .{n});
    if (g.retried) |n| try w.print(" data-retried=\"{d}\"", .{n});
    if (g.retry_skipped) |n| try w.print(" data-retry-skipped=\"{d}\"", .{n});
    if (g.reconstructed) try w.writeAll(" data-recon=\"1\"");
    if (chart.eventAt(&chart.events, g.n)) |label| {
        try w.writeAll(" data-event=\"");
        try html.text(w, label);
        try w.writeAll("\"");
    }
    try w.print("><td>{d}</td><td>", .{g.n});
    try html.shortDateY(w, g.at);
    try w.writeAll("</td><td>");
    if (g.since.len > 0) {
        try rangeLink(w, g.since, g.head);
        if (g.landed.len > 0) {
            try w.writeAll("<span class=\"landed\">merged ");
            try landedList(w, g.landed, false);
            try w.writeAll("</span>");
        }
    } else if (known_head) {
        try w.writeAll("<code>");
        try html.text(w, g.head);
        try w.writeAll("</code>");
    } else try w.writeAll("reconstructed");
    const est = g.estimated();
    try w.writeAll("</td><td>");
    try html.num(w, g.passing());
    try w.writeAll(if (est) "</td><td class=\"est\">" else "</td><td>");
    try html.num(w, g.subTotal());
    try w.writeAll(if (est) "</td><td class=\"est fail\">" else "</td><td class=\"fail\">");
    try html.num(w, g.subTotal() - g.passing());
    try w.writeAll("</td><td class=\"blk\">");
    try html.num(w, g.blocking);
    try w.writeAll("</td><td class=\"flaky\">");
    if (g.flaky) |n| try html.num(w, n) else try w.writeAll("&mdash;");
    if (g.retried) |r| {
        // The count beside what was asked of it: a flaky number shrinks when fewer files are retried.
        try w.writeAll(" <small class=\"dim\">of ");
        try html.num(w, r);
        try w.writeAll(" retried");
        if (g.retry_skipped) |k| if (k > 0) {
            try w.writeAll(", ");
            try html.num(w, k);
            try w.writeAll(" skipped");
        };
        try w.writeAll("</small>");
    }
    try w.writeAll("</td></tr>\n");
}

// ============================================================================
// Directory pages
// ============================================================================

pub fn writeDirPage(w: W, site: *const Site, d: *const DirView) Error!void {
    var rbuf: [3 * 64]u8 = undefined;
    const root = rootFor(&rbuf, depthOf(d.path));
    const suite = d.path[0 .. (std.mem.indexOfScalar(u8, d.path, '/') orelse d.path.len) + 1];
    const suite_no = site.suiteNo(suite);
    // A suite's own directories are numbered N.i, as its index section numbers them.
    var number_buf: [32]u8 = undefined;
    const number: ?[]const u8 = blk: {
        const n = suite_no orelse break :blk null;
        if (std.mem.eql(u8, d.path, suite)) break :blk std.fmt.bufPrint(&number_buf, "{d}", .{n}) catch null;
        if (depthOf(d.path) == 2) {
            for (site.dir(suite).dirs, 1..) |c, i| if (std.mem.eql(u8, c, d.path)) break :blk std.fmt.bufPrint(&number_buf, "{d}.{d}", .{ n, i }) catch null;
        }
        break :blk null;
    };

    var title_buf: [512]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "{s} - Crane WPT Results", .{d.path}) catch "Crane WPT Results";
    try writeHead(w, .{ .root = root, .title = title, .description = "Crane's web-platform-tests results for one directory of the WPT tree: its subtest numbers, and every subdirectory and test file in it." });
    try w.writeAll("</head>\n<body>\n<div class=\"frame\">\n<main class=\"doc\" id=\"main\">\n<header class=\"head head-page\">\n");
    try writeCrumbs(w, root, d.path, false);
    try w.writeAll("<h1 class=\"page-title\">");
    if (number) |n| try w.print("<span class=\"secno\">{s}</span>", .{n});
    try html.path(w, d.path);
    try w.writeAll("</h1>\n");
    try writeFigures(w, d.path, Figures.ofTotals(d.totals));
    try writeRefFigures(w, site, d.ref_totals);
    try w.writeAll("</header>\n<div class=\"boxes\">\n");
    try writeConformance(w, d.path, d.totals);
    try w.writeAll("<div class=\"box tests\">\n<div class=\"box-head\"><h2 class=\"box-title\">Tests</h2><span class=\"box-sub\">");
    if (d.dirs.len > 0) {
        try html.plural(w, d.dirs.len, "directory", "directories");
        if (d.files.len > 0) try w.writeAll(", ");
    }
    if (d.files.len > 0) {
        try html.plural(w, d.files.len, "test file", "test files");
        try w.writeAll(" here");
    }
    try w.writeAll("</span></div>\n");
    try writeDirTable(w, site, root, d.dirs, if (std.mem.eql(u8, d.path, suite)) suite_no else null, false);
    try writeFileTable(w, site, root, d.files, false);
    try w.writeAll("</div>\n</div>\n");
    try writeClose(w, site, root, suite);
}

// ============================================================================
// Test file pages
// ============================================================================

pub fn writeFilePage(w: W, site: *const Site, f: *const FileView, runs: []const SubtestRun) Error!void {
    var rbuf: [3 * 64]u8 = undefined;
    const root = rootFor(&rbuf, depthOf(f.path) + 1);
    const suite = f.path[0 .. (std.mem.indexOfScalar(u8, f.path, '/') orelse 0) + 1];

    var title_buf: [600]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "{s} - Crane WPT Results", .{f.path}) catch "Crane WPT Results";
    try writeHead(w, .{ .root = root, .title = title, .description = "Crane's web-platform-tests result for one test file: its subtest numbers, and each subtest's status and failure message." });
    try w.writeAll("</head>\n<body>\n<div class=\"frame\">\n<main class=\"doc\" id=\"main\">\n<header class=\"head head-page\">\n");
    try writeCrumbs(w, root, f.path, true);
    try w.writeAll("<h1 class=\"page-title\">");
    try html.path(w, baseName(f.path));
    try w.writeAll("</h1>\n");
    const c = f.counts;
    try writeFigures(w, f.path, .{ .pass = c.passed, .reported = c.reported(), .failed = c.failed, .timed_out = c.timed_out, .notrun = c.notrun });

    try w.writeAll("<dl class=\"file-meta\">\n<div><dt>Standing</dt><dd>");
    try gateSpan(w, f.gate);
    if (f.status) |st| {
        try w.writeAll(" <span class=\"quiet\">runner status <code>");
        try html.text(w, st);
        try w.writeAll("</code></span>");
    }
    try w.writeAll("</dd></div>\n");
    try writeRefStanding(w, site, f);
    try w.writeAll("<div><dt>Run</dt><dd>");
    if (f.run) |rid| {
        try w.writeAll("<code>");
        try html.text(w, rid);
        try w.writeAll("</code>");
        if (site.runs.get(rid)) |r| {
            try w.writeAll(", <span class=\"nowrap\">");
            try html.shortDateY(w, r.date);
            try w.writeAll("</span>, Crane ");
            try commitLink(w, r.commit);
        }
    } else try w.writeAll("not run yet");
    try w.writeAll("</dd></div>\n<div><dt>Test source</dt><dd><a href=\"");
    try sourceUrl(w, site, f.path);
    try w.writeAll("\">");
    try html.path(w, f.path);
    try w.writeAll("</a></dd></div>\n</dl>\n");
    if (f.exemption) |e| {
        try w.writeAll("<div class=\"note\" role=\"note\"><p class=\"note-label\">Exempt from the 0.1 gate</p>\n");
        try writeEvidence(w, e);
        try w.writeAll("</div>\n");
    }
    if (f.message) |m| {
        try w.writeAll("<div class=\"harness\"><p class=\"harness-label\">Harness message</p><pre class=\"msg\">");
        try html.text(w, m);
        try w.writeAll("</pre></div>\n");
    }
    try w.writeAll("</header>\n<section class=\"subtests-section\" aria-labelledby=\"subtests-h\">\n<h2 id=\"subtests-h\">Subtests</h2>\n");

    if (runs.len == 0) {
        try w.writeAll("<p class=\"no-detail\"><strong>No per-subtest data for this file.</strong> ");
        if (f.status == null) {
            try w.writeAll("It has no result yet.");
        } else if (c.reported() == 0) {
            try w.writeAll("Its latest run reported no subtests.");
        } else {
            try w.writeAll("Its latest run recorded counts only: ");
            try html.num(w, c.passed);
            try w.writeAll(" passed, ");
            try html.num(w, c.failed);
            try w.writeAll(" failed, ");
            try html.num(w, c.timed_out);
            try w.writeAll(" timed out and ");
            try html.num(w, c.notrun);
            try w.writeAll(" did not run. Subtest names and failure messages arrive with the first run that writes result streams.");
        }
        try w.writeAll("</p>\n");
    } else {
        try w.writeAll("<p class=\"sub-hint\">Each subtest that failed opens in place to its message.</p>\n");
        var ids = IdSet{};
        for (runs) |r| try writeRun(w, r, runs.len > 1, &ids);
    }
    try w.writeAll("</section>\n");
    try writeClose(w, site, root, suite);
}

/// Subtest ids, made unique within their page: a hash of the test URL and
/// the name, stable across regenerations, with a suffix for a repeated name.
const IdSet = struct {
    seen: [4096]u32 = undefined,
    n: usize = 0,
    overflow: u32 = 0,

    fn make(s: *IdSet, buf: []u8, test_url: []const u8, name: []const u8) []const u8 {
        var h = std.hash.Wyhash.init(0x5eed);
        h.update(test_url);
        h.update("\x00");
        h.update(name);
        const v: u32 = @truncate(h.final());
        var dup: u32 = 0;
        for (s.seen[0..s.n]) |x| if (x == v) {
            dup += 1;
        };
        if (s.n < s.seen.len) {
            s.seen[s.n] = v;
            s.n += 1;
        }
        if (dup == 0) return std.fmt.bufPrint(buf, "s-{x:0>8}", .{v}) catch unreachable;
        return std.fmt.bufPrint(buf, "s-{x:0>8}-{d}", .{ v, dup + 1 }) catch unreachable;
    }
};

fn writeRun(w: W, r: SubtestRun, multi: bool, ids: *IdSet) Error!void {
    try w.writeAll("<div class=\"run\">\n");
    if (multi or !std.mem.eql(u8, r.status, "OK")) {
        try w.writeAll("<h3 class=\"run-head\"><code>");
        try html.text(w, r.test_url);
        try w.print("</code> <span class=\"gate{s}\">", .{if (std.mem.eql(u8, r.status, "OK")) "" else " g-block"});
        try html.text(w, r.status);
        try w.writeAll("</span> <span class=\"fcount\">");
        try writePassOf(w, r.pass, r.total);
        try w.writeAll("</span></h3>\n");
    }
    if (r.message) |m| {
        try w.writeAll("<pre class=\"msg harness-msg\">");
        try html.text(w, m);
        try w.writeAll("</pre>\n");
    }
    if (r.subtests.len > 0) {
        try w.writeAll("<ol class=\"subtests\">\n");
        for (r.subtests) |s| {
            var idbuf: [32]u8 = undefined;
            const id = ids.make(&idbuf, r.test_url, s.name);
            try w.print("<li class=\"sub {s}\" id=\"{s}\">", .{ markClass(s.status), id });
            if (s.message) |m| {
                try w.print("<details><summary><span class=\"mark\">{s}</span><span class=\"sub-name\">", .{markWord(s.status)});
                try html.text(w, s.name);
                try w.writeAll("</span></summary><pre class=\"msg\">");
                try html.text(w, m);
                try w.writeAll("</pre></details>");
            } else {
                try w.print("<div class=\"sub-line\"><span class=\"mark\">{s}</span><span class=\"sub-name\">", .{markWord(s.status)});
                try html.text(w, s.name);
                try w.writeAll("</span></div>");
            }
            try w.print("<a class=\"self\" href=\"#{s}\" aria-label=\"Link to this subtest\">&para;</a></li>\n", .{id});
        }
        try w.writeAll("</ol>\n");
    }
    if (r.passing_omitted > 0) {
        try w.writeAll("<p class=\"omitted\">");
        try html.plural(w, r.passing_omitted, "passing subtest is", "passing subtests are");
        try w.print(" not listed: this file has more than {d} subtests, so only those that did not pass are kept.</p>\n", .{model.detail_limit});
    }
    if (r.subtests.len == 0 and r.passing_omitted == 0) try w.writeAll("<p class=\"omitted\">No subtests were reported.</p>\n");
    try w.writeAll("</div>\n");
}

// ============================================================================
// A reference run beside Crane's
// ============================================================================

/// A file page's row for the reference run: its standing and subtests, or
/// that it has none.
fn writeRefStanding(w: W, site: *const Site, f: *const FileView) Error!void {
    const r = site.reference orelse return;
    try w.print("<div><dt>{s}</dt><dd>", .{r.label()});
    const rv = f.ref orelse return w.writeAll("<span class=\"quiet\">no result in the reference run</span></dd></div>\n");
    try gateSpan(w, rv.gate);
    try w.writeByte(' ');
    try writePassOf(w, rv.counts.passed, rv.counts.reported());
    try w.writeAll(" WPT subtests passing <span class=\"quiet\">runner status <code>");
    try html.text(w, rv.status);
    try w.writeAll("</code></span>");
    if (rv.missing_urls > 0) {
        try w.writeAll(" <span class=\"quiet\">");
        try html.num(w, rv.missing_urls);
        try w.print(" of its test URLs {s} no {s} result</span>", .{ if (rv.missing_urls == 1) "has" else "have", r.label() });
    }
    try w.writeAll("</dd></div>\n");
}

/// A duration as people say it: "250 ms", "1.50 s", "40 min 0 s", "2 h 20 min".
fn writeDuration(w: W, secs: f64) Error!void {
    if (!(secs >= 0)) return w.writeAll("&mdash;");
    if (secs < 1) return w.print("{d} ms", .{@as(u64, @intFromFloat(@round(secs * 1000)))});
    if (secs < 10) return w.print("{d:.2} s", .{secs});
    if (secs < 60) return w.print("{d:.1} s", .{secs});
    const whole: u64 = @intFromFloat(@round(secs));
    if (whole < 3600) return w.print("{d} min {d} s", .{ whole / 60, whole % 60 });
    return w.print("{d} h {d} min", .{ whole / 3600, (whole % 3600) / 60 });
}

fn writeVersusRow(w: W, label: []const u8, crane: u64, ref: u64, cls: []const u8) Error!void {
    try w.print("<tr><th scope=\"row\">{s}</th>", .{label});
    for ([_]u64{ crane, ref }) |v| {
        try w.print("<td class=\"n{s}{s}\">", .{ if (v > 0 and cls.len > 0) " " else "", if (v > 0) cls else "" });
        try html.num(w, v);
        try w.writeAll("</td>");
    }
    try w.writeAll("</tr>\n");
}

fn sumPassDiff(site: *const Site, list: []const usize, ref_ahead: bool) u64 {
    var n: u64 = 0;
    for (list) |i| {
        const f = site.files[i];
        const rv = f.ref orelse continue;
        n += if (ref_ahead) rv.counts.passed -| f.counts.passed else f.counts.passed -| rv.counts.passed;
    }
    return n;
}

fn writeTimeRow(w: W, label: []const u8, crane: ?f64, ref: ?f64) Error!void {
    try w.print("<tr><th scope=\"row\">{s}</th>", .{label});
    for ([_]?f64{ crane, ref }) |v| {
        try w.writeAll("<td class=\"n\">");
        if (v) |x| try writeDuration(w, x) else try w.writeAll("<span class=\"quiet\">not measured</span>");
        try w.writeAll("</td>");
    }
    try w.writeAll("</tr>\n");
}

/// The run's identity, in a sentence: the engine, its version and driver,
/// the runner, when and where, and the WPT tree.
fn writeRunIdentity(w: W, r: *const reference_mod.Reference) Error!void {
    const run = r.run;
    try w.print("{s} <code>", .{r.label()});
    try html.text(w, run.browser_version);
    try w.writeAll("</code>");
    if (run.channel.len > 0) {
        try w.writeAll(" (");
        try html.text(w, run.channel);
        try w.writeAll(")");
    }
    const cov = r.coverage;
    if (cov.sources_reported < cov.sources) {
        try w.writeAll(" has a result for ");
        try html.num(w, cov.sources_reported);
        try w.writeAll(" of the worklist&rsquo;s ");
        try html.plural(w, cov.sources, "test file", "test files");
        try w.writeAll(", run");
    } else {
        try w.writeAll(" ran the worklist&rsquo;s ");
        try html.plural(w, cov.sources, "test file", "test files");
    }
    try w.writeAll(" on <span class=\"nowrap\">");
    try html.shortDateY(w, run.date);
    try w.writeAll("</span> with WPT&rsquo;s own runner (<code>wpt run</code>, headless");
    if (run.webdriver_version.len > 0) {
        try w.print(", {s} <code>", .{if (std.mem.eql(u8, r.engine, "chrome")) "ChromeDriver" else "WebDriver"});
        try html.text(w, run.webdriver_version);
        try w.writeAll("</code>");
    }
    try w.print(", {d} processes", .{run.processes});
    if (run.host.len > 0) {
        try w.writeAll(", ");
        try html.text(w, run.host);
    }
    try w.writeAll("), on WPT revision <a href=\"" ++ links.wpt_fork ++ "/tree/");
    try html.href(w, run.wpt_revision);
    try w.writeAll("\"><code>");
    try html.text(w, run.wpt_revision[0..@min(10, run.wpt_revision.len)]);
    try w.writeAll("</code></a>, over the worklist of Crane ");
    try commitLink(w, run.worklist_commit);
    try w.writeAll(".");
    // The Crane runner the window timed beside it (`main-<sha>`, a frozen main).
    if (r.timing) |tm| if (tm.crane) |c| if (c.runner.len > 0) {
        try w.writeAll(" In the same window Crane&rsquo;s frozen runner, ");
        if (model.labelCommit(c.runner)) |sha| {
            try html.text(w, c.runner[0 .. c.runner.len - sha.len - 1]);
            try w.writeByte(' ');
            try commitLink(w, sha);
        } else {
            try w.writeAll("<code>");
            try html.text(w, c.runner);
            try w.writeAll("</code>");
        }
        try w.writeAll(", ran the same files with the same runners.");
    };
}

/// The index's comparison with the reference run: both engines' numbers on
/// the same files, where they differ, and what the runs cost.
fn writeVersus(w: W, site: *const Site) Error!void {
    const r = site.reference orelse return;
    // Over the files both have a result for: the same files, so the numbers compare.
    const tot = site.both_crane;
    const rt = site.both_ref;
    const name = r.label();
    try w.print("<section class=\"front\" id=\"versus\" aria-labelledby=\"versus-h\">\n<h2 id=\"versus-h\">Crane and {s}</h2>\n<div class=\"front-prose\">\n<p>", .{name});
    try writeRunIdentity(w, r);
    try w.print(" Its results are a reference: they are read only from <code>wpt-results/reference/</code>, never counted as Crane&rsquo;s, and every number here says whose it is.</p>\n<p>", .{});
    try w.print("<a href=\"{s}.html#ahead-ref\">", .{r.engine});
    try html.plural(w, site.ahead_ref.len, "file", "files");
    try w.print("</a> where {s} passes subtests Crane does not (", .{name});
    try html.plural(w, sumPassDiff(site, site.ahead_ref, true), "subtest", "subtests");
    try w.print("); <a href=\"{s}.html#ahead-crane\">", .{r.engine});
    try html.plural(w, site.ahead_crane.len, "file", "files");
    try w.print("</a> where Crane passes subtests {s} does not (", .{name});
    try html.plural(w, sumPassDiff(site, site.ahead_crane, false), "subtest", "subtests");
    try w.print("). Not compared: <a href=\"{s}.html#only-one\">", .{r.engine});
    try html.plural(w, site.only_ref.len, "file", "files");
    try w.print("</a> with a result from {s} alone, ", .{name});
    try html.num(w, site.only_crane.len);
    try w.writeAll(" from Crane alone.</p>\n</div>\n<div class=\"versus-boxes\">\n");

    // The numbers, side by side.
    try w.print("<div class=\"box versus-box\">\n<div class=\"box-head\"><h3 class=\"box-title\">The same files</h3><span class=\"box-sub\">", .{});
    try html.plural(w, site.both, "test file", "test files");
    try w.print(" both ran</span></div>\n<table class=\"versus\">\n<thead><tr><td></td><th scope=\"col\" class=\"n\">Crane</th><th scope=\"col\" class=\"n\">{s}</th></tr></thead>\n<tbody>\n", .{name});
    try w.writeAll("<tr><th scope=\"row\">WPT subtests passing</th>");
    for ([_]model.Totals{ tot, rt }) |t| {
        try w.print("<td class=\"n\" data-v=\"{d}\" data-of=\"{d}\">", .{ t.sub_pass, t.subReported() });
        try writePassOf(w, t.sub_pass, t.subReported());
        try w.writeAll("</td>");
    }
    try w.writeAll("</tr>\n");
    try writeVersusRow(w, "Failed", tot.sub_fail, rt.sub_fail, "fail");
    try writeVersusRow(w, "Timed out", tot.sub_timeout, rt.sub_timeout, "");
    try writeVersusRow(w, "Not run", tot.sub_notrun, rt.sub_notrun, "");
    try writeVersusRow(w, "Blocking files", tot.blocking(), rt.blocking(), "blk");
    try writeVersusRow(w, "Clean files", tot.clean, rt.clean, "");
    try w.writeAll("</tbody>\n</table>\n</div>\n");

    // What the runs cost.
    if (r.timing) |tm| {
        try w.print("<div class=\"box versus-box\">\n<div class=\"box-head\"><h3 class=\"box-title\">Wall time</h3><span class=\"box-sub\">{d} runners each", .{tm.processes});
        if (r.run.host.len > 0) {
            try w.writeAll(", ");
            try html.text(w, r.run.host);
        }
        try w.print("</span></div>\n<table class=\"versus\">\n<thead><tr><td></td><th scope=\"col\" class=\"n\">Crane</th><th scope=\"col\" class=\"n\">{s}</th></tr></thead>\n<tbody>\n", .{name});
        const cw: ?f64 = if (tm.crane) |c| c.wall_s else null;
        const cc: ?f64 = if (tm.crane) |c| c.cpu() else null;
        try writeTimeRow(w, "The worklist, wall clock", cw, tm.reference.wall_s);
        try writeTimeRow(w, "CPU, user + system", cc, tm.reference.cpu());
        const urls = r.coverage.urls_expected;
        if (tm.overhead) |o| if (o.files > 0) {
            const hc = reference_mod.harnessOf(o, true);
            const hr = reference_mod.harnessOf(o, false);
            const procs: f64 = @floatFromInt(tm.processes);
            try writeTimeRow(w, "One empty test, harness alone", hc.per_test_s * procs, hr.per_test_s * procs);
            if (o.small_files > 0) try writeTimeRow(w, "Start-up, before the first test", hc.startup_s, hr.startup_s);
            // Each run is split over the test URLs it ran (the worklist's, when it recorded none).
            const ur = if (tm.reference.tests > 0) tm.reference.tests else urls;
            const uc = if (tm.crane) |c| (if (c.tests > 0) c.tests else urls) else urls;
            if (ur > 0) {
                try writeTimeRow(w, "Of the wall clock: harness (estimate)", hc.of(uc), hr.of(ur));
                try writeTimeRow(w, "Of the wall clock: the tests (estimate)", if (cw) |x| @max(x - hc.of(uc), 0) else null, @max(tm.reference.wall_s - hr.of(ur), 0));
            }
        };
        try w.writeAll("</tbody>\n</table>\n</div>\n");
    }
    try w.writeAll("</div>\n<div class=\"note\" role=\"note\">\n<p class=\"note-label\">How the two are compared</p>\n<p>Both counts are per file, over the same test URLs: each global and variant of a file is one test, and a file&rsquo;s URLs are summed as Crane&rsquo;s runner sums them, the worst status winning. ");
    const c = r.coverage;
    try w.print("{s} reported ", .{name});
    try html.num(w, c.urls_reported);
    try w.writeAll(" of the ");
    try html.num(w, c.urls_expected);
    try w.writeAll(" test URLs of these files");
    if (c.urls_missing > 0) {
        try w.writeAll("; the other ");
        try html.num(w, c.urls_missing);
        try w.writeAll(" have no result, and each file page says when its count covers fewer URLs");
    }
    try w.writeAll(". Each engine runs under its own harness: Crane&rsquo;s runner, and WPT&rsquo;s <code>wptrunner</code> driving the browser over WebDriver.");
    if (r.timing) |tm| if (tm.overhead) |o| {
        try w.writeAll(" To read the wall clock honestly, each harness also ran ");
        try html.num(w, o.files);
        try w.print(" files holding one empty test (<code>tests/wpt/crane/harness-overhead/</code>) with the same {d} runners: what one costs is the harness alone, and the estimates split each run&rsquo;s wall clock at that rate over its ", .{tm.processes});
        try html.num(w, c.urls_expected);
        try w.writeAll(" test URLs.");
    };
    try w.writeAll("</p>\n</div>\n</section>\n");
}

/// Most severe first, as site.js sorts a standing column.
fn gateRank(g: model.Gate) u8 {
    return switch (g) {
        .crash => 8,
        .err => 7,
        .timeout => 6,
        .none_passed => 5,
        .exempt => 4,
        .unrun => 3,
        .partial => 2,
        .empty => 1,
        .clean => 0,
    };
}

fn writeCompareRow(w: W, f: FileView, ref_ahead: bool) Error!void {
    const rv = f.ref.?;
    try w.print("<tr data-gate=\"{s}\"><th scope=\"row\"><a href=\"", .{f.gate.word()});
    try html.href(w, f.path);
    try w.writeAll("/\">");
    try html.path(w, f.path);
    try w.writeAll("</a></th>");
    try w.print("<td class=\"n\" data-v=\"{d}\" data-of=\"{d}\">", .{ f.counts.passed, f.counts.reported() });
    try writePassOf(w, f.counts.passed, f.counts.reported());
    try w.print("</td><td class=\"n\" data-v=\"{d}\" data-of=\"{d}\">", .{ rv.counts.passed, rv.counts.reported() });
    try writePassOf(w, rv.counts.passed, rv.counts.reported());
    const d = if (ref_ahead) rv.counts.passed -| f.counts.passed else f.counts.passed -| rv.counts.passed;
    try w.print("</td><td class=\"n\" data-v=\"{d}\">+", .{d});
    try html.num(w, d);
    try w.print("</td><td data-v=\"{d}\">", .{gateRank(f.gate)});
    try gateSpan(w, f.gate);
    try w.print("</td><td data-v=\"{d}\">", .{gateRank(rv.gate)});
    try gateSpan(w, rv.gate);
    try w.writeAll("</td></tr>\n");
}

fn writeCompareTable(w: W, site: *const Site, list: []const usize, ref_ahead: bool) Error!void {
    const name = site.reference.?.label();
    if (list.len == 0) return w.writeAll("<p class=\"quiet\">None.</p>\n");
    try w.print("<table class=\"listing listing-compare\">\n<thead><tr><th scope=\"col\">Test file</th><th scope=\"col\" class=\"n\">Crane</th><th scope=\"col\" class=\"n\">{s}</th><th scope=\"col\" class=\"n\">{s} ahead by</th><th scope=\"col\">Crane standing</th><th scope=\"col\">{s} standing</th></tr></thead>\n<tbody>\n", .{ name, if (ref_ahead) name else "Crane", name });
    for (list) |i| try writeCompareRow(w, site.files[i], ref_ahead);
    try w.writeAll("</tbody>\n</table>\n");
}

fn writeOnlyList(w: W, site: *const Site, list: []const usize, ref_side: bool) Error!void {
    if (list.len == 0) return w.writeAll("<p class=\"quiet\">None.</p>\n");
    try w.writeAll("<table class=\"listing listing-compare\">\n<thead><tr><th scope=\"col\">Test file</th><th scope=\"col\" class=\"n\">Subtests passing</th><th scope=\"col\">Standing</th></tr></thead>\n<tbody>\n");
    for (list) |i| {
        const f = site.files[i];
        const c = if (ref_side) f.ref.?.counts else f.counts;
        const g = if (ref_side) f.ref.?.gate else f.gate;
        try w.writeAll("<tr><th scope=\"row\"><a href=\"");
        try html.href(w, f.path);
        try w.writeAll("/\">");
        try html.path(w, f.path);
        try w.print("</a></th><td class=\"n\" data-v=\"{d}\" data-of=\"{d}\">", .{ c.passed, c.reported() });
        try writePassOf(w, c.passed, c.reported());
        try w.print("</td><td data-v=\"{d}\">", .{gateRank(g)});
        try gateSpan(w, g);
        try w.writeAll("</td></tr>\n");
    }
    try w.writeAll("</tbody>\n</table>\n");
}

/// `<engine>.html`: every file the two engines differ on, in both directions,
/// and the files only one of them ran.
pub fn writeComparePage(w: W, site: *const Site) Error!void {
    const r = site.reference orelse return;
    const name = r.label();
    var title_buf: [128]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Crane and {s} - Crane WPT Results", .{name}) catch "Crane WPT Results";
    try writeHead(w, .{ .root = "", .title = title, .description = "Crane's web-platform-tests results beside a browser's on the same files: every file where one passes subtests the other does not." });
    try w.writeAll("</head>\n<body>\n<div class=\"frame\">\n<main class=\"doc\" id=\"main\">\n<header class=\"head head-page\">\n");
    try w.print("<nav class=\"crumbs\" aria-label=\"Breadcrumb\"><ol><li><a href=\"./\">Crane WPT results</a></li><li aria-current=\"page\">Crane and {s}</li></ol></nav>\n", .{name});
    try w.print("<h1 class=\"page-title\">Crane and {s}</h1>\n", .{name});
    const tot = site.root().totals;
    try writeFigures(w, "Crane", Figures.ofTotals(tot));
    try writeRefFigures(w, site, site.root().ref_totals);
    try w.writeAll("<p class=\"compare-lede\">");
    try writeRunIdentity(w, r);
    try w.writeAll(" Its results are a reference, never counted as Crane&rsquo;s. A file is listed where the two pass different numbers of its subtests; the same count can still hide different subtests, which each file&rsquo;s page shows for Crane.</p>\n</header>\n");

    try w.print("<section class=\"compare\" id=\"ahead-ref\" aria-labelledby=\"ahead-ref-h\">\n<h2 id=\"ahead-ref-h\">Where {s} passes subtests Crane does not</h2>\n<p>", .{name});
    try html.plural(w, site.ahead_ref.len, "file", "files");
    try w.writeAll(", ");
    try html.plural(w, sumPassDiff(site, site.ahead_ref, true), "subtest", "subtests");
    try w.print(" in all: the work that would bring Crane level with {s} here, the most first.</p>\n", .{name});
    try writeCompareTable(w, site, site.ahead_ref, true);
    try w.writeAll("</section>\n");

    try w.print("<section class=\"compare\" id=\"ahead-crane\" aria-labelledby=\"ahead-crane-h\">\n<h2 id=\"ahead-crane-h\">Where Crane passes subtests {s} does not</h2>\n<p>", .{name});
    try html.plural(w, site.ahead_crane.len, "file", "files");
    try w.writeAll(", ");
    try html.plural(w, sumPassDiff(site, site.ahead_crane, false), "subtest", "subtests");
    try w.writeAll(" in all, the most first.</p>\n");
    try writeCompareTable(w, site, site.ahead_crane, false);
    try w.writeAll("</section>\n");

    try w.writeAll("<section class=\"compare\" id=\"only-one\" aria-labelledby=\"only-one-h\">\n<h2 id=\"only-one-h\">Files only one of them ran</h2>\n");
    try w.print("<h3>{s} has a result, Crane has none</h3>\n", .{name});
    try writeOnlyList(w, site, site.only_ref, true);
    try w.print("<h3>Crane has a result, {s} has none</h3>\n", .{name});
    try writeOnlyList(w, site, site.only_crane, false);
    try w.writeAll("</section>\n");
    try writeClose(w, site, "", null);
}

// ============================================================================
// The no-script rule
// ============================================================================

/// Why `page` would need script to show its content, or null when it does
/// not. A page may load the enhancement script - one `<script src="…site.js"
/// defer>`, which runs after the page has rendered and only adds to it - and
/// nothing else of the kind. The generator's tests run this over every page.
pub fn needsScript(page: []const u8) ?[]const u8 {
    var scripts: usize = 0;
    var at: usize = 0;
    while (std.mem.indexOfPos(u8, page, at, "<script")) |i| : (at = i + 1) {
        scripts += 1;
        const end = std.mem.indexOfPos(u8, page, i, "</script>") orelse return "an unclosed script";
        const tag = page[i .. end + "</script>".len];
        const ok = std.mem.startsWith(u8, tag, "<script src=\"") and
            std.mem.endsWith(u8, tag, "site.js\" defer></script>") and
            std.mem.indexOfScalar(u8, tag["<script src=\"".len .. tag.len - "\" defer></script>".len], '"') == null;
        if (!ok) return "a script other than the deferred enhancement script";
    }
    if (scripts > 1) return "more than one script";
    const markers = [_]struct { []const u8, []const u8 }{
        .{ "<noscript", "a noscript fallback" },
        .{ "data-fill", "a slot for script to fill" },
        .{ "Loading", "a loading placeholder" },
        .{ "&hellip;</", "an ellipsis placeholder" },
        .{ "javascript:", "a javascript: URL" },
        .{ " onclick=", "an inline event handler" },
        .{ " onload=", "an inline event handler" },
        .{ ".json\"", "a link to data for script" },
    };
    for (markers) |m| if (std.mem.indexOf(u8, page, m[0]) != null) return m[1];
    return null;
}

test "needsScript: the enhancement script is allowed; anything content would wait on is not" {
    try std.testing.expect(needsScript("<p>1,234</p>") == null);
    try std.testing.expect(needsScript("<script src=\"../site.js\" defer></script><p>1,234</p>") == null);
    try std.testing.expectEqualStrings("a script other than the deferred enhancement script", needsScript("<script>document.write(1)</script>").?);
    try std.testing.expectEqualStrings("a script other than the deferred enhancement script", needsScript("<script src=\"site.js\"></script>").?);
    try std.testing.expectEqualStrings("more than one script", needsScript("<script src=\"site.js\" defer></script><script src=\"site.js\" defer></script>").?);
    try std.testing.expectEqualStrings("a slot for script to fill", needsScript("<dd data-fill=\"hl-pass\"></dd>").?);
    try std.testing.expectEqualStrings("a loading placeholder", needsScript("<p>Loading the results</p>").?);
}
