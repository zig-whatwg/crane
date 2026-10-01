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
};

pub const DirView = struct {
    /// "dom/nodes/"; "" is the root.
    path: []const u8,
    totals: model.Totals = .{},
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

const reserved_ids = [_][]const u8{ "status", "contents", "history", "main", "toc", "gens", "chart", "hl-label", "toc-title" };

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

fn segments(t: model.Totals) [5]Seg {
    return .{
        .{ .class = "m-clean", .v = t.clean },
        .{ .class = "m-partial", .v = t.partial },
        .{ .class = "m-empty", .v = t.empty },
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
    try w.writeAll(" not run, of ");
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

/// The directories table. `base` is the href prefix from the page to the
/// site root; `number_under` numbers the rows N.i when the list is a suite's.
fn writeDirTable(w: W, site: *const Site, base: []const u8, dirs: []const []const u8, number_under: ?usize, row_ids: bool) Error!void {
    if (dirs.len == 0) return;
    try w.writeAll("<table class=\"listing listing-dirs\">\n<thead><tr><th scope=\"col\">Directory</th><th scope=\"col\" class=\"n\">Subtests passing</th><th scope=\"col\" class=\"n\">Test files</th><th scope=\"col\">Standing</th></tr></thead>\n<tbody>\n");
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
        try w.print("</td><td class=\"n\" data-v=\"{d}\">", .{t.files});
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
    try w.writeAll("<table class=\"listing listing-files\">\n<thead><tr><th scope=\"col\">Test file</th><th scope=\"col\" class=\"n\">Subtests passing</th><th scope=\"col\" class=\"n\">Failed</th><th scope=\"col\">Standing</th></tr></thead>\n<tbody>\n");
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
        try w.print("</td><td class=\"n\" data-v=\"{d}\">", .{f.counts.failed});
        if (f.counts.failed > 0) {
            try w.writeAll("<span class=\"fail\">");
            try html.num(w, f.counts.failed);
            try w.writeAll("</span>");
        } else try w.writeAll("<span class=\"quiet\">0</span>");
        try w.print("</td><td data-v=\"{d}\">", .{@intFromEnum(f.gate)});
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
    const f = Figures.ofTotals(tot);
    const g = site.latest();

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
    try commitLink(w, g.head);
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
    try w.writeAll(" subtests its runs reported. This is not a browser comparison");
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
    try w.writeAll(" today. Per-subtest detail comes from the runner&rsquo;s result streams: ");
    if (site.detail_files > 0) {
        try html.num(w, site.detail_files);
        try w.writeAll(" of ");
        try html.num(w, tot.files);
        try w.writeAll(" files have it in this generation.");
    } else {
        try w.writeAll("no file has it in this generation yet, so each file&rsquo;s page gives its counts.");
    }
    try w.writeAll("</p>\n</div>\n<div class=\"note\" role=\"note\">\n<p class=\"note-label\">How to read a section</p>\n<p>Each suite is a numbered section that opens with its own subtest numbers. Its <em>Conformance</em> box counts files by standing; its <em>Tests</em> tables link to a page for every directory and every test file, and a test file&rsquo;s page lists its subtests. Everything has a permanent link, <span class=\"self-demo\" aria-hidden=\"true\">&para;</span>.</p>\n<dl class=\"legend\" aria-label=\"File standings\">\n<div><dt><span class=\"key key-clean\"></span>Clean</dt><dd>every reported subtest passed</dd></div>\n<div><dt><span class=\"key key-partial\"></span>With failures</dt><dd>some subtests passed, some did not</dd></div>\n<div><dt><span class=\"key key-blocking\"></span>Blocking</dt><dd>NONE-PASSED, TIMEOUT, ERROR, CRASH</dd></div>\n<div><dt><span class=\"key key-empty\"></span>No subtests</dt><dd>the file ran and reported none</dd></div>\n<div><dt><span class=\"key key-unrun\"></span>Not run</dt><dd>no result yet</dd></div>\n</dl>\n</div>\n</section>\n");
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
    for ([_][]const u8{ "Gen.", "Date", "Crane", "Subtests passing", "Total subtests", "Not passing", "Blocking files" }) |h| {
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
    try w.print(" data-pass=\"{d}\" data-total=\"{d}\"", .{ g.passing(), g.subTotal() });
    if (g.subs) |sb| {
        try w.print(" data-fail=\"{d}\" data-timeout=\"{d}\" data-notrun=\"{d}\"", .{ sb.failed, sb.timed_out, sb.notrun });
    } else try w.writeAll(" data-est=\"1\"");
    try w.print(" data-blocking=\"{d}\" data-files=\"{d}\"", .{ g.blocking, g.total });
    if (g.reconstructed) try w.writeAll(" data-recon=\"1\"");
    if (chart.eventAt(&chart.events, g.n)) |label| {
        try w.writeAll(" data-event=\"");
        try html.text(w, label);
        try w.writeAll("\"");
    }
    try w.print("><td>{d}</td><td>", .{g.n});
    try html.shortDateY(w, g.at);
    try w.writeAll("</td><td>");
    if (known_head) {
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
    try w.writeAll("</dd></div>\n<div><dt>Run</dt><dd>");
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
