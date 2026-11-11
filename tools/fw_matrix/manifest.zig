//! The manifest, tools/fw_matrix/frameworks.zon: its SUITES, each a row's
//! measurement - a framework (the matrix row) may have more than one: the
//! project's own browser suite (jQuery's QUnit pages, htmx's Mocha page) and
//! later Crane's port of the TodoMVC app spec on the framework's prebuilt
//! TodoMVC app (the user, 2026-11-11 09:57 ET); `kind` says which, and every
//! journal record carries it. Per suite: the pinned version (tag and
//! commit), the files a run needs - the tag's source
//! tarball and the published files its test page loads - each with its
//! sha256 (ruling R8: fetched by checksum, never vendored), the files the
//! project's Node build would write and this tool writes instead (ruling
//! R3), the resources the page loads live from another origin (ruling R6),
//! the pages to open, the reader, and the exclusion list.
//!
//! Every ruling is one switch here: R3 the `generated` entries; R4/R7 the
//! `skip_kinds` (a kind left out runs its listed tests); R6
//! `allow_live_loads`.

const std = @import("std");
const Allocator = std.mem.Allocator;
const exclusions = @import("exclusions.zig");
const generated = @import("generated.zig");
const journal = @import("journal.zig");

pub const Archive = struct {
    url: []const u8,
    sha256: []const u8,
    /// Paths below the tarball's top directory left out of the tree
    /// (htmx's www/: the web site, 217 MB, no test needs it).
    skip: []const []const u8 = &.{},
};

pub const FileMap = struct {
    /// The path inside the archive (npm: "package/...").
    from: []const u8,
    /// The path below the framework's tree.
    to: []const u8,
};

/// A published file set the project's own copy step puts into its tree
/// (jQuery's build/tasks/npmcopy.js), from the npm registry.
pub const Dependency = struct {
    name: []const u8,
    version: []const u8,
    url: []const u8,
    sha256: []const u8,
    /// The project's lockfile pin (package-lock.json `integrity`), checked
    /// too when present.
    integrity: ?[]const u8 = null,
    files: []const FileMap,
};

pub const Generated = struct {
    kind: generated.Kind,
    from: []const u8,
    to: []const u8,
};

/// A resource the page loads from another origin by its own markup; the
/// harness fetches it beforehand only to check its sha256 (ruling R6).
pub const Remote = struct {
    url: []const u8,
    sha256: []const u8,
};

/// A directory of the Crane repository served at a path prefix beside the
/// suite's fetched tree: Crane's own page for a suite whose tests are ours
/// (the TodoMVC port, tests/frameworks/todomvc/, beside the prebuilt app it
/// drives - one origin, as a test page and its app share in Cypress's own
/// runner). Requests below `prefix` are answered from `dir`, never from the
/// tree; the tree is never written to.
pub const Overlay = struct {
    /// The URL path below the root ("crane/todomvc" -> /crane/todomvc/...).
    prefix: []const u8,
    /// The directory, relative to the repository root `fw_matrix` runs in.
    dir: []const u8,
};

pub const Page = struct {
    /// Short and unique within the framework ("css", "test").
    id: []const u8,
    /// Path and query below the tree's root, as the project opens it.
    path: []const u8,
    /// QUnit: the module the page selects (`?module=`), whose exclusions
    /// it applies; null for a page that runs everything.
    module: ?[]const u8 = null,
};

pub const Suite = struct {
    /// Unique, and the tree's directory name with the version
    /// ("jquery-qunit" -> ~/crane-frameworks/jquery-qunit-4.0.0/).
    id: []const u8,
    /// The matrix row it belongs to ("jquery").
    framework: []const u8,
    /// The framework's display name ("jQuery").
    title: []const u8,
    /// The framework's version as this suite runs it.
    version: []const u8,
    kind: journal.SuiteKind,
    repository: []const u8,
    tag: []const u8,
    commit: []const u8,
    licence: []const u8,
    /// "QUnit 2.24.2", "Mocha 11.7.5 + Chai 4.5.0".
    runner: []const u8,
    reader: exclusions.Reader,
    source: Archive,
    dependencies: []const Dependency = &.{},
    generated: []const Generated = &.{},
    remote: []const Remote = &.{},
    allow_live_loads: bool = false,
    overlay: []const Overlay = &.{},
    pages: []const Page,
    /// The exclusion list's file name below tools/fw_matrix/excluded/.
    excluded: []const u8,
    /// The kinds of listed tests a run skips through the framework's filter.
    skip_kinds: []const exclusions.Kind = &.{ .rendering, .needs_server, .needs_node_build, .node_runner_only },
    /// How long one page may run before it is ended, in seconds.
    page_budget_s: u32 = 900,
    /// How long a page may show no progress before it is ended, in seconds
    /// (longer than the framework's own per-test timeout: QUnit's 60 s in
    /// jQuery's testrunner.js).
    page_stall_s: u32 = 150,
};

pub const Manifest = struct {
    suites: []const Suite,
};

pub const Error = error{ OutOfMemory, ParseZon, BadName, BadSha256, BadPath, BadUrl, DuplicatePage, DuplicateSuite, NoPages, LiveLoadsNotAllowed, BadIntegrity, OverlappingOverlay };

pub const Failure = struct {
    suite: []const u8 = "",
    what: []const u8 = "",
    diagnostics: std.zon.parse.Diagnostics = .{ .errors = &.{} },
};

pub fn parse(gpa: Allocator, arena: Allocator, source: [:0]const u8, failure: *Failure) Error!Manifest {
    const m = try std.zon.parse.fromSlice(Manifest, .{ .gpa = gpa, .arena = arena, .source = source, .diagnostics = &failure.diagnostics });
    try validate(m, failure);
    return m;
}

fn isName(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (!(std.ascii.isLower(c) or std.ascii.isDigit(c) or c == '-' or c == '.' or c == '_')) return false;
    return true;
}

/// A relative path that stays below its root.
pub fn isRelativePath(s: []const u8) bool {
    if (s.len == 0 or s[0] == '/') return false;
    var it = std.mem.splitScalar(u8, s, '/');
    while (it.next()) |seg| if (seg.len == 0 or std.mem.eql(u8, seg, "..") or std.mem.eql(u8, seg, ".")) return false;
    for (s) |c| if (c == '\\' or c == 0) return false;
    return true;
}

/// `path` is `prefix` or below it ("crane/todomvc/x" is below "crane";
/// "cranex" is not).
pub fn underPrefix(path: []const u8, prefix: []const u8) bool {
    if (!std.mem.startsWith(u8, path, prefix)) return false;
    return path.len == prefix.len or path[prefix.len] == '/';
}

fn isHttps(s: []const u8) bool {
    return std.mem.startsWith(u8, s, "https://") and std.mem.indexOfAny(u8, s, " \t\n\"'") == null;
}

pub fn validate(m: Manifest, failure: *Failure) Error!void {
    for (m.suites, 0..) |f, i| {
        failure.suite = f.id;
        failure.what = "id";
        if (!isName(f.id) or !isName(f.framework) or !isName(f.version)) return error.BadName;
        for (m.suites[0..i]) |o| if (std.mem.eql(u8, o.id, f.id)) return error.DuplicateSuite;
        failure.what = "source";
        if (!isHttps(f.source.url)) return error.BadUrl;
        if (!journal.isSha256(f.source.sha256)) return error.BadSha256;
        for (f.source.skip) |s| if (!isRelativePath(s)) return error.BadPath;
        for (f.dependencies) |d| {
            failure.what = d.name;
            if (!isHttps(d.url)) return error.BadUrl;
            if (!journal.isSha256(d.sha256)) return error.BadSha256;
            if (d.integrity) |integ| if (!std.mem.startsWith(u8, integ, "sha512-")) return error.BadIntegrity;
            for (d.files) |fm| if (!isRelativePath(fm.from) or !isRelativePath(fm.to)) return error.BadPath;
        }
        for (f.generated) |g| {
            failure.what = g.to;
            if (!isRelativePath(g.from) or !isRelativePath(g.to)) return error.BadPath;
        }
        for (f.remote) |r| {
            failure.what = r.url;
            if (!isHttps(r.url)) return error.BadUrl;
            if (!journal.isSha256(r.sha256)) return error.BadSha256;
        }
        for (f.overlay, 0..) |o, j| {
            failure.what = o.prefix;
            if (!isRelativePath(o.prefix) or !isRelativePath(o.dir)) return error.BadPath;
            // One prefix inside another would leave which directory answers
            // a path to the order of the list.
            for (f.overlay[0..j]) |p| if (underPrefix(o.prefix, p.prefix) or underPrefix(p.prefix, o.prefix)) return error.OverlappingOverlay;
        }
        failure.what = "pages";
        if (f.pages.len == 0) return error.NoPages;
        for (f.pages, 0..) |p, j| {
            failure.what = p.id;
            if (!isName(p.id)) return error.BadName;
            const path_part = p.path[0 .. std.mem.indexOfScalar(u8, p.path, '?') orelse p.path.len];
            if (!isRelativePath(path_part)) return error.BadPath;
            for (f.pages[0..j]) |o| if (std.mem.eql(u8, o.id, p.id)) return error.DuplicatePage;
        }
        failure.what = "excluded";
        if (!isRelativePath(f.excluded)) return error.BadPath;
    }
    failure.* = .{ .diagnostics = failure.diagnostics };
}

pub fn find(m: Manifest, id: []const u8) ?Suite {
    for (m.suites) |f| if (std.mem.eql(u8, f.id, id)) return f;
    return null;
}

/// The suite's tree below the frameworks directory: "<id>-<version>".
pub fn treeName(arena: Allocator, f: Suite) ![]const u8 {
    return std.fmt.allocPrint(arena, "{s}-{s}", .{ f.id, f.version });
}

const testing = std.testing;

const sample =
    \\.{
    \\    .suites = .{
    \\        .{
    \\            .id = "jquery-qunit",
    \\            .framework = "jquery",
    \\            .title = "jQuery",
    \\            .version = "4.0.0",
    \\            .kind = .project,
    \\            .repository = "https://github.com/jquery/jquery",
    \\            .tag = "4.0.0",
    \\            .commit = "4f2fae08f23b54ce09322e62e73cce6161b8d3cb",
    \\            .licence = "MIT",
    \\            .runner = "QUnit 2.24.2",
    \\            .reader = .qunit,
    \\            .source = .{ .url = "https://codeload.github.com/jquery/jquery/tar.gz/refs/tags/4.0.0", .sha256 = "76e03838f1acf056339e5ca3c829115365f0ce3a4cd51112d52ad1d8d8cf6abe" },
    \\            .dependencies = .{
    \\                .{ .name = "qunit", .version = "2.24.2", .url = "https://registry.npmjs.org/qunit/-/qunit-2.24.2.tgz", .sha256 = "0bb099b1f142144e552e15d3d7025d5ec8a87773fa38ba4415b5d5e5bfe1d667", .integrity = "sha512-x", .files = .{.{ .from = "package/qunit/qunit.js", .to = "external/qunit/qunit.js" }} },
    \\            },
    \\            .generated = .{.{ .kind = .qunit_fixture, .from = "test/data/qunit-fixture.html", .to = "test/data/qunit-fixture.js" }},
    \\            .pages = .{ .{ .id = "basic", .path = "test/index.html?module=basic", .module = "basic" } },
    \\            .excluded = "jquery-4.0.0.txt",
    \\            .skip_kinds = .{ .rendering, .needs_server },
    \\        },
    \\    },
    \\}
;

test "parse: a suite with its pins; defaults filled in" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    var f: Failure = .{};
    const m = try parse(testing.allocator, arena_state.allocator(), sample, &f);
    const jq = find(m, "jquery-qunit").?;
    try testing.expectEqual(journal.SuiteKind.project, jq.kind);
    try testing.expectEqual(exclusions.Reader.qunit, jq.reader);
    try testing.expectEqual(@as(usize, 1), jq.dependencies.len);
    try testing.expectEqual(generated.Kind.qunit_fixture, jq.generated[0].kind);
    try testing.expectEqualStrings("basic", jq.pages[0].module.?);
    try testing.expectEqual(@as(usize, 2), jq.skip_kinds.len);
    try testing.expectEqual(@as(u32, 900), jq.page_budget_s);
    try testing.expect(!jq.allow_live_loads);
    try testing.expectEqualStrings("jquery-qunit-4.0.0", try treeName(arena_state.allocator(), jq));
}

test "parse: an overlay - a directory of the repository served at a path prefix beside the tree" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const with_overlay = try std.mem.replaceOwned(u8, a, sample, ".excluded = \"jquery-4.0.0.txt\",", ".excluded = \"jquery-4.0.0.txt\", .overlay = .{.{ .prefix = \"crane/todomvc\", .dir = \"tests/frameworks/todomvc\" }},");
    var f: Failure = .{};
    const m = try parse(testing.allocator, a, try a.dupeSentinel(u8, with_overlay, 0), &f);
    const jq = find(m, "jquery-qunit").?;
    try testing.expectEqual(@as(usize, 1), jq.overlay.len);
    try testing.expectEqualStrings("crane/todomvc", jq.overlay[0].prefix);
    try testing.expectEqualStrings("tests/frameworks/todomvc", jq.overlay[0].dir);
    // None by default.
    const plain = try parse(testing.allocator, a, sample, &f);
    try testing.expectEqual(@as(usize, 0), find(plain, "jquery-qunit").?.overlay.len);

    // A prefix or directory that leaves its root, and two overlays where one
    // prefix holds the other, are refused.
    const bad = [_]struct { []const u8, Error }{
        .{ ".{ .prefix = \"../x\", .dir = \"tests/frameworks/todomvc\" }", error.BadPath },
        .{ ".{ .prefix = \"crane/todomvc\", .dir = \"/etc\" }", error.BadPath },
        .{ ".{ .prefix = \"crane\", .dir = \"a\" }, .{ .prefix = \"crane/todomvc\", .dir = \"b\" }", error.OverlappingOverlay },
    };
    for (bad) |c| {
        const text = try std.mem.replaceOwned(u8, a, sample, ".excluded = \"jquery-4.0.0.txt\",", try std.fmt.allocPrint(a, ".excluded = \"jquery-4.0.0.txt\", .overlay = .{{ {s} }},", .{c[0]}));
        var f2: Failure = .{};
        try testing.expectError(c[1], parse(testing.allocator, a, try a.dupeSentinel(u8, text, 0), &f2));
        try testing.expectEqualStrings("jquery-qunit", f2.suite);
    }
}

test "validate refuses a bad checksum, a path out of the tree, plain http and duplicates" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const cases = [_]struct { []const u8, []const u8, Error }{
        .{ "76e03838f1acf056339e5ca3c829115365f0ce3a4cd51112d52ad1d8d8cf6abe\"", "76E03838f1acf056339e5ca3c829115365f0ce3a4cd51112d52ad1d8d8cf6abe\"", error.BadSha256 },
        .{ "\"external/qunit/qunit.js\"", "\"../qunit.js\"", error.BadPath },
        .{ "\"https://registry.npmjs.org/qunit", "\"http://registry.npmjs.org/qunit", error.BadUrl },
        .{ "\"sha512-x\"", "\"sha1-x\"", error.BadIntegrity },
        .{ ".{ .{ .id = \"basic\", .path = \"test/index.html?module=basic\", .module = \"basic\" } }", ".{ .{ .id = \"basic\", .path = \"a.html\" }, .{ .id = \"basic\", .path = \"b.html\" } }", error.DuplicatePage },
    };
    for (cases) |c| {
        const bad = try std.mem.replaceOwned(u8, a, sample, c[0], c[1]);
        try testing.expect(!std.mem.eql(u8, bad, sample));
        const z = try a.dupeSentinel(u8, bad, 0);
        var f: Failure = .{};
        try testing.expectError(c[2], parse(testing.allocator, a, z, &f));
        try testing.expectEqualStrings("jquery-qunit", f.suite);
    }
    try testing.expect(isRelativePath("test/index.html"));
    try testing.expect(!isRelativePath("test//index.html"));
    try testing.expect(!isRelativePath("/etc"));
    try testing.expect(!isRelativePath("a/./b"));
}
