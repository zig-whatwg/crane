//! The suite: tests/perf/suite.json, the list of pages the runner launches
//! each engine on, with the workloads each page declares and how to run it.
//! The same file drives every engine, so every engine runs the same work.
//!
//! `check` holds the suite to its pages: every page exists, declares each
//! workload the suite lists for it (`perf.add('<name>'`, `perf.chain(...`,
//! `perf.idle(...`), and declares no workload the suite does not list - a
//! workload added to a page but not to the suite would silently never run.

const std = @import("std");
const Allocator = std.mem.Allocator;
const journal = @import("journal.zig");

pub const format_name = "crane-perf-suite/1";

pub const PageKind = enum {
    /// In-page timed workloads (`perf.add`), run one after another.
    timed,
    /// A navigation chain (`perf.chain`): the page navigates to itself
    /// `steps` times, one cold document per step.
    chain,
    /// The page loads and is left alone for `settle_ms` (`perf.idle`).
    idle,
    /// `instances` engines side by side on the page, each left idle.
    instances,
    /// Objects made and kept (`perf.retain`): the page makes `count` of
    /// them and keeps them, and the footprint is read once before and once
    /// after - each reading after a collection where the engine lets a page
    /// ask for one, and `settle_ms` of idle time (docs/performance.md,
    /// "Memory per element").
    retained,
};

pub const Page = struct {
    /// Relative to tests/perf/.
    page: []const u8,
    kind: PageKind,
    workloads: []const []const u8,
    /// The most the page may take, launch to its last mark.
    timeout_s: u32 = 300,
    /// chain: how many documents.
    steps: u32 = 0,
    /// idle, instances: how long the page is left before the footprint is
    /// read.
    settle_ms: u32 = 0,
    /// instances: how many engines side by side.
    instances: u32 = 0,
    /// retained: how many objects the page makes and keeps - the same
    /// number in every engine (it is on the page's URL).
    count: u32 = 0,
};

pub const Suite = struct {
    format: []const u8,
    pages: []const Page,
};

pub const Error = error{
    WrongFormat,
    NoPages,
    BadPagePath,
    BadWorkloadName,
    DuplicateWorkload,
    NoWorkloads,
    ChainWithoutSteps,
    IdleWithoutSettle,
    InstancesBelowTwo,
    OneWorkloadPerPage,
    RetainedWithoutCount,
};

pub fn parse(arena: Allocator, bytes: []const u8) !Suite {
    const s = try std.json.parseFromSliceLeaky(Suite, arena, bytes, .{});
    try validate(s);
    return s;
}

pub fn validate(s: Suite) Error!void {
    if (!std.mem.eql(u8, s.format, format_name)) return error.WrongFormat;
    if (s.pages.len == 0) return error.NoPages;
    for (s.pages, 0..) |p, i| {
        if (p.page.len == 0 or p.page[0] == '/' or std.mem.indexOf(u8, p.page, "..") != null) return error.BadPagePath;
        if (p.workloads.len == 0) return error.NoWorkloads;
        for (p.workloads) |w| {
            if (!journal.isWorkloadName(w)) return error.BadWorkloadName;
            // A workload is one row of the report: listed once in the suite.
            for (s.pages[0..i]) |q| for (q.workloads) |v| if (std.mem.eql(u8, v, w)) return error.DuplicateWorkload;
        }
        switch (p.kind) {
            .timed => {},
            .chain => {
                if (p.steps == 0) return error.ChainWithoutSteps;
                if (p.workloads.len != 1) return error.OneWorkloadPerPage;
            },
            .idle => {
                if (p.settle_ms == 0) return error.IdleWithoutSettle;
                if (p.workloads.len != 1) return error.OneWorkloadPerPage;
            },
            .instances => {
                if (p.instances < 2) return error.InstancesBelowTwo;
                if (p.settle_ms == 0) return error.IdleWithoutSettle;
                if (p.workloads.len != 1) return error.OneWorkloadPerPage;
            },
            // One case per page, so each is a fresh process: memory freed
            // in one case stays in the footprint (an allocator keeps what
            // it was given), and a second case in the same process would
            // reuse it and read as smaller.
            .retained => {
                if (p.count == 0) return error.RetainedWithoutCount;
                if (p.settle_ms == 0) return error.IdleWithoutSettle;
                if (p.workloads.len != 1) return error.OneWorkloadPerPage;
            },
        }
    }
}

/// The harness call that declares a workload of this kind in a page.
fn declarer(kind: PageKind) []const u8 {
    return switch (kind) {
        .timed => "perf.add(",
        .chain => "perf.chain(",
        .idle, .instances => "perf.idle(",
        .retained => "perf.retain(",
    };
}

/// The workload names a page's source declares with `call` ("perf.add("),
/// in order: the string literal right after each call.
pub fn declared(arena: Allocator, source: []const u8, call: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var at: usize = 0;
    while (std.mem.indexOfPos(u8, source, at, call)) |i| {
        at = i + call.len;
        var j = at;
        while (j < source.len and (source[j] == ' ' or source[j] == '\n')) j += 1;
        if (j >= source.len or (source[j] != '\'' and source[j] != '"')) continue;
        const quote = source[j];
        const end = std.mem.indexOfScalarPos(u8, source, j + 1, quote) orelse continue;
        try out.append(arena, source[j + 1 .. end]);
        at = end + 1;
    }
    return out.items;
}

/// A problem `check` found: the page and what is wrong.
pub const Problem = struct {
    page: []const u8,
    what: []const u8,
    workload: []const u8 = "",
};

/// Every page of the suite read through `readPage` (a page path ->
/// its source, or null when it does not exist), and the problems found.
pub fn check(arena: Allocator, s: Suite, ctx: anytype, readPage: fn (@TypeOf(ctx), Allocator, []const u8) ?[]const u8) ![]const Problem {
    var problems: std.ArrayList(Problem) = .empty;
    for (s.pages) |p| {
        const source = readPage(ctx, arena, p.page) orelse {
            try problems.append(arena, .{ .page = p.page, .what = "page does not exist" });
            continue;
        };
        const names = try declared(arena, source, declarer(p.kind));
        for (p.workloads) |w| {
            const found = for (names) |n| {
                if (std.mem.eql(u8, n, w)) break true;
            } else false;
            if (!found) try problems.append(arena, .{ .page = p.page, .what = "the suite lists a workload the page does not declare", .workload = w });
        }
        for (names) |n| {
            const listed = for (p.workloads) |w| {
                if (std.mem.eql(u8, n, w)) break true;
            } else false;
            if (!listed) try problems.append(arena, .{ .page = p.page, .what = "the page declares a workload the suite does not list", .workload = n });
        }
    }
    return problems.items;
}

const testing = std.testing;

const sample =
    \\{"format":"crane-perf-suite/1","pages":[
    \\ {"page":"workloads/attributes.html","kind":"timed","workloads":["dom.getter-loop","dom.setter-loop"]},
    \\ {"page":"load/news.html","kind":"chain","steps":10,"workloads":["load.news"]},
    \\ {"page":"memory/idle.html","kind":"idle","settle_ms":3000,"workloads":["memory.idle-page"]},
    \\ {"page":"memory/instance.html","kind":"instances","instances":4,"settle_ms":3000,"workloads":["memory.instances"]}
    \\]}
;

test "a suite parses, with each kind's defaults" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const s = try parse(arena.allocator(), sample);
    try testing.expectEqual(@as(usize, 4), s.pages.len);
    try testing.expectEqual(PageKind.chain, s.pages[1].kind);
    try testing.expectEqual(@as(u32, 10), s.pages[1].steps);
    try testing.expectEqual(@as(u32, 300), s.pages[0].timeout_s);
}

test "a suite's rules" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectError(error.WrongFormat, parse(a, "{\"format\":\"x\",\"pages\":[]}"));
    try testing.expectError(error.NoPages, parse(a, "{\"format\":\"crane-perf-suite/1\",\"pages\":[]}"));
    try testing.expectError(error.DuplicateWorkload, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"a.html","kind":"timed","workloads":["x.a"]},{"page":"b.html","kind":"timed","workloads":["x.a"]}]}
    ));
    try testing.expectError(error.ChainWithoutSteps, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"a.html","kind":"chain","workloads":["x.a"]}]}
    ));
    try testing.expectError(error.InstancesBelowTwo, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"a.html","kind":"instances","instances":1,"settle_ms":10,"workloads":["x.a"]}]}
    ));
    try testing.expectError(error.BadPagePath, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"../a.html","kind":"timed","workloads":["x.a"]}]}
    ));
    try testing.expectError(error.BadWorkloadName, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"a.html","kind":"timed","workloads":["Xa"]}]}
    ));
    try testing.expectError(error.RetainedWithoutCount, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"a.html","kind":"retained","settle_ms":10,"workloads":["x.a"]}]}
    ));
    try testing.expectError(error.IdleWithoutSettle, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"a.html","kind":"retained","count":10,"workloads":["x.a"]}]}
    ));
    try testing.expectError(error.OneWorkloadPerPage, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"a.html","kind":"retained","count":10,"settle_ms":10,"workloads":["x.a","x.b"]}]}
    ));
    try testing.expectError(error.UnknownField, parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"a.html","kind":"timed","workloads":["x.a"],"step":3}]}
    ));
}

test "the names a page declares" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const src = "perf.add('dom.a', { ops: 1 });\nperf.add(\"dom.b\", {});\nperf.add(name, {});\nperf.chain('load.x');";
    const names = try declared(arena.allocator(), src, "perf.add(");
    try testing.expectEqual(@as(usize, 2), names.len);
    try testing.expectEqualStrings("dom.a", names[0]);
    try testing.expectEqualStrings("dom.b", names[1]);
}

test "a retained page: one case, its count and its settle time" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const s = try parse(a,
        \\{"format":"crane-perf-suite/1","pages":[{"page":"memory/elements-detached-div.html","kind":"retained","count":100000,"settle_ms":3000,"workloads":["elements.detached-div"]}]}
    );
    try testing.expectEqual(PageKind.retained, s.pages[0].kind);
    try testing.expectEqual(@as(u32, 100000), s.pages[0].count);
    // The page declares its case with perf.retain(...).
    const pages = [_][2][]const u8{.{ "memory/elements-detached-div.html", "perf.retain('elements.detached-div', cases.detachedDiv);" }};
    try testing.expectEqual(@as(usize, 0), (try check(a, s, @as([]const [2][]const u8, &pages), Pages.read)).len);
    const undeclared = [_][2][]const u8{.{ "memory/elements-detached-div.html", "perf.add('elements.detached-div', {});" }};
    try testing.expectEqual(@as(usize, 1), (try check(a, s, @as([]const [2][]const u8, &undeclared), Pages.read)).len);
}

const Pages = struct {
    fn read(pages: []const [2][]const u8, _: Allocator, path: []const u8) ?[]const u8 {
        for (pages) |p| if (std.mem.eql(u8, p[0], path)) return p[1];
        return null;
    }
};

test "check: a page that is missing, a workload not declared, a workload not listed" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const s = try parse(a, sample);
    const pages = [_][2][]const u8{
        .{ "workloads/attributes.html", "perf.add('dom.getter-loop', {}); perf.add('dom.extra', {});" },
        .{ "load/news.html", "perf.chain('load.news');" },
    };
    const problems = try check(a, s, @as([]const [2][]const u8, &pages), Pages.read);
    // attributes: dom.setter-loop not declared, dom.extra not listed;
    // memory/idle.html and memory/instance.html missing.
    try testing.expectEqual(@as(usize, 4), problems.len);
    try testing.expectEqualStrings("dom.setter-loop", problems[0].workload);
    try testing.expectEqualStrings("dom.extra", problems[1].workload);
    try testing.expectEqualStrings("page does not exist", problems[2].what);
}

test "check: a suite and pages that agree have no problems" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const s = try parse(a, sample);
    const pages = [_][2][]const u8{
        .{ "workloads/attributes.html", "perf.add('dom.getter-loop', {}); perf.add('dom.setter-loop', {});" },
        .{ "load/news.html", "perf.chain('load.news');" },
        .{ "memory/idle.html", "perf.idle('memory.idle-page');" },
        .{ "memory/instance.html", "perf.idle('memory.instances');" },
    };
    const problems = try check(a, s, @as([]const [2][]const u8, &pages), Pages.read);
    try testing.expectEqual(@as(usize, 0), problems.len);
}
