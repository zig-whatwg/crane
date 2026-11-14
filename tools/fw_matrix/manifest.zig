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
//! `allow_live_loads`; the user's of 2026-11-11 17:43 ET ("we can run node
//! for the purposes of these tests") the `node`, `npm` and `server` entries:
//! Node pinned by checksum, the project's own dependencies installed from its
//! own lockfile, and its own test server run in place of the harness's
//! static one - for the framework tests only, never for Crane itself.

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

/// Node.js, for a suite whose own tooling runs under it (the user,
/// 2026-11-11 17:43 ET: "we can run node for the purposes of these tests" -
/// the framework matrix only, never Crane's engine or its other tools):
/// nodejs.org's release tarball per host platform, by the sha256 its
/// SHASUMS256.txt gives.
pub const NodeArchive = struct {
    /// Node's own platform name: "linux-x64", "darwin-arm64".
    platform: []const u8,
    url: []const u8,
    sha256: []const u8,
};

pub const Node = struct {
    /// "24.22.3" (no "v").
    version: []const u8,
    archives: []const NodeArchive,

    /// The archive for a host, by Node's platform name (fetch.nodePlatform).
    pub fn archiveFor(n: Node, platform: []const u8) ?NodeArchive {
        for (n.archives) |a| if (std.mem.eql(u8, a.platform, platform)) return a;
        return null;
    }
};

/// The project's own dependencies, installed by `npm ci` from its own
/// lockfile (npm checks every package against the lockfile's `integrity`),
/// and the project's own npm scripts run after the install.
pub const Npm = struct {
    /// The sha256 of the tree's package-lock.json, checked before the
    /// install (it comes in the tag's tarball; pinned here so the pin is
    /// read where every other pin is).
    lockfile_sha256: []const u8,
    /// `npm run <script>`, each in order after the install (jQuery's
    /// `babel:tests`, the step of its `pretest` that writes a test page's
    /// transpiled script).
    scripts: []const []const u8 = &.{},
};

/// The project's own test server, run in the suite's tree instead of the
/// harness's static server (jQuery: jquery-test-runner's `jtr serve -m
/// test/middleware-mockserver.cjs`, its `npm run test:server`).
pub const ExternalServer = struct {
    /// What it is, for the journal and the report ("jquery-test-runner
    /// 0.3.0").
    name: []const u8,
    /// The command, run in the tree. Its first argument is a path below the
    /// tree (the project's own installed command: "node_modules/.bin/jtr"),
    /// never a name PATH resolves. Each "{port}" in an argument becomes the
    /// port the harness picks - never a fixed one. Node's bin directory
    /// leads its PATH (a `#!/usr/bin/env node` command finds the pinned
    /// Node).
    argv: []const []const u8,
    /// A path whose GET answering (any HTTP status) means it is up; asked
    /// of 127.0.0.1.
    ready_path: []const u8 = "/",
    /// How long it may take to answer, in seconds.
    ready_s: u32 = 60,
    /// The host the page URLs name: the one the project's own runner opens
    /// (jquery-test-runner's lib/buildTestUrl.js: "localhost"; jQuery's
    /// "jQuery.append with crossorigin attribute" runs only there, reaching
    /// 127.0.0.1 as its other origin).
    host: []const u8 = "localhost",
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
    node: ?Node = null,
    npm: ?Npm = null,
    /// The project's own test server; null: the harness's static server.
    server: ?ExternalServer = null,
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

pub const Error = error{ OutOfMemory, ParseZon, BadName, BadSha256, BadPath, BadUrl, DuplicatePage, DuplicateSuite, NoPages, LiveLoadsNotAllowed, BadIntegrity, OverlappingOverlay, NpmWithoutNode, ServerWithoutNode, BadServer, ServerWithoutPort, ServerWithOverlay };

/// The text a server argument holds where the harness's port goes.
pub const port_placeholder = "{port}";

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

/// A page's path part (before its query): a relative path below the tree,
/// which may end in "/" - a directory, as jquery-test-runner opens
/// "test/?module=<m>".
fn isPagePath(path_part: []const u8) bool {
    const trimmed = if (std.mem.endsWith(u8, path_part, "/")) path_part[0 .. path_part.len - 1] else path_part;
    return isRelativePath(trimmed);
}

/// The file a page path opens: a directory's index.html.
pub fn pageFile(arena: Allocator, path: []const u8) ![]const u8 {
    const path_part = path[0 .. std.mem.indexOfScalar(u8, path, '?') orelse path.len];
    if (std.mem.endsWith(u8, path_part, "/")) return std.fmt.allocPrint(arena, "{s}index.html", .{path_part});
    return path_part;
}

/// "24.22.3": three numbers.
fn isVersion(s: []const u8) bool {
    var it = std.mem.splitScalar(u8, s, '.');
    var n: usize = 0;
    while (it.next()) |part| : (n += 1) {
        if (part.len == 0) return false;
        for (part) |c| if (!std.ascii.isDigit(c)) return false;
    }
    return n == 3;
}

/// An npm script's name as `npm run` takes it ("babel:tests"): one word.
fn isScriptName(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (!(std.ascii.isAlphanumeric(c) or c == ':' or c == '-' or c == '_' or c == '.')) return false;
    return true;
}

/// A host name for a page URL ("localhost", "127.0.0.1").
fn isHost(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (!(std.ascii.isLower(c) or std.ascii.isDigit(c) or c == '.' or c == '-')) return false;
    return true;
}

fn validateNode(n: Node, failure: *Failure) Error!void {
    failure.what = "node";
    if (!isVersion(n.version) or n.archives.len == 0) return error.BadName;
    for (n.archives, 0..) |a, i| {
        failure.what = a.platform;
        if (!isName(a.platform)) return error.BadName;
        if (!isHttps(a.url)) return error.BadUrl;
        if (!journal.isSha256(a.sha256)) return error.BadSha256;
        for (n.archives[0..i]) |o| if (std.mem.eql(u8, o.platform, a.platform)) return error.BadName;
    }
}

fn validateServer(s: ExternalServer, failure: *Failure) Error!void {
    failure.what = "server";
    if (s.name.len == 0 or s.argv.len == 0) return error.BadServer;
    // The tree's own command, by its path below the tree.
    if (!isRelativePath(s.argv[0]) or std.mem.indexOfScalar(u8, s.argv[0], '/') == null) return error.BadServer;
    if (s.ready_path.len == 0 or s.ready_path[0] != '/' or std.mem.indexOfAny(u8, s.ready_path, " \t\r\n") != null) return error.BadServer;
    if (s.ready_s == 0 or !isHost(s.host)) return error.BadServer;
    var has_port = false;
    for (s.argv) |arg| {
        if (std.mem.indexOfScalar(u8, arg, 0) != null) return error.BadServer;
        if (std.mem.indexOf(u8, arg, port_placeholder) != null) has_port = true;
    }
    if (!has_port) return error.ServerWithoutPort;
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
        if (f.node) |n| try validateNode(n, failure);
        if (f.npm) |n| {
            failure.what = "npm";
            if (f.node == null) return error.NpmWithoutNode;
            if (!journal.isSha256(n.lockfile_sha256)) return error.BadSha256;
            for (n.scripts) |s| if (!isScriptName(s)) return error.BadName;
        }
        if (f.server) |s| {
            failure.what = "server";
            if (f.node == null) return error.ServerWithoutNode;
            // The project's server serves the tree alone: an overlay is the
            // harness's static server's.
            if (f.overlay.len > 0) return error.ServerWithOverlay;
            try validateServer(s, failure);
        }
        failure.what = "pages";
        if (f.pages.len == 0) return error.NoPages;
        for (f.pages, 0..) |p, j| {
            failure.what = p.id;
            if (!isName(p.id)) return error.BadName;
            const path_part = p.path[0 .. std.mem.indexOfScalar(u8, p.path, '?') orelse p.path.len];
            if (!isPagePath(path_part)) return error.BadPath;
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

/// The sample with `extra` fields added to its suite (before `.excluded`).
fn withFields(a: Allocator, extra: []const u8) ![:0]const u8 {
    const text = try std.mem.replaceOwned(u8, a, sample, ".excluded = \"jquery-4.0.0.txt\",", try std.fmt.allocPrint(a, "{s} .excluded = \"jquery-4.0.0.txt\",", .{extra}));
    return a.dupeSentinel(u8, text, 0);
}

const node_fields =
    \\.node = .{ .version = "24.22.3", .archives = .{
    \\    .{ .platform = "linux-x64", .url = "https://nodejs.org/dist/v24.22.3/node-v24.22.3-linux-x64.tar.gz", .sha256 = "061ec3e3062115705b56b51fa9cc330ab50d34b6969387d4e4b1a50c6809acc2" },
    \\} },
;
const npm_fields =
    \\.npm = .{ .lockfile_sha256 = "b0b0be0c8e8c4ba6a3a23c4ac7a1178a0dd7fb7fa14f22ed66404df5e52a991b", .scripts = .{"babel:tests"} },
;
const server_fields =
    \\.server = .{ .name = "jquery-test-runner 0.3.0", .argv = .{ "node_modules/.bin/jtr", "serve", "-m", "test/middleware-mockserver.cjs", "--port", "{port}" }, .ready_path = "/test/" },
;

test "parse: Node, npm and the project's own server; their defaults" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var f: Failure = .{};
    const m = try parse(testing.allocator, a, try withFields(a, node_fields ++ npm_fields ++ server_fields), &f);
    const jq = find(m, "jquery-qunit").?;
    try testing.expectEqualStrings("24.22.3", jq.node.?.version);
    try testing.expectEqualStrings("linux-x64", jq.node.?.archives[0].platform);
    try testing.expectEqualStrings("babel:tests", jq.npm.?.scripts[0]);
    const s = jq.server.?;
    try testing.expectEqualStrings("node_modules/.bin/jtr", s.argv[0]);
    try testing.expectEqualStrings("/test/", s.ready_path);
    // The page URLs name the host the project's own runner opens
    // (jquery-test-runner lib/buildTestUrl.js: "localhost").
    try testing.expectEqualStrings("localhost", s.host);
    try testing.expectEqual(@as(u32, 60), s.ready_s);
    // None of them by default.
    const plain = find(try parse(testing.allocator, a, sample, &f), "jquery-qunit").?;
    try testing.expect(plain.node == null and plain.npm == null and plain.server == null);
    // The archive for a platform, by Node's own platform name.
    try testing.expectEqualStrings("061ec3e3062115705b56b51fa9cc330ab50d34b6969387d4e4b1a50c6809acc2", jq.node.?.archiveFor("linux-x64").?.sha256);
    try testing.expectEqual(@as(?NodeArchive, null), jq.node.?.archiveFor("darwin-arm64"));
}

test "validate: npm and a server need Node; a server takes its port from the harness and is not an overlay's suite" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const cases = [_]struct { []const u8, Error }{
        .{ npm_fields, error.NpmWithoutNode },
        .{ server_fields, error.ServerWithoutNode },
        // A fixed port: the harness picks one per run.
        .{ node_fields ++ ".server = .{ .name = \"s\", .argv = .{ \"node_modules/.bin/jtr\", \"serve\", \"--port\", \"3000\" } },", error.ServerWithoutPort },
        // The command must be the tree's own (a relative path below it):
        // never a bare name PATH would resolve, never a host's absolute path.
        .{ node_fields ++ ".server = .{ .name = \"s\", .argv = .{ \"jtr\", \"{port}\" } },", error.BadServer },
        .{ node_fields ++ ".server = .{ .name = \"s\", .argv = .{ \"/usr/bin/jtr\", \"{port}\" } },", error.BadServer },
        .{ node_fields ++ ".server = .{ .name = \"s\", .argv = .{ \"../jtr\", \"{port}\" } },", error.BadServer },
        .{ node_fields ++ ".server = .{ .name = \"\", .argv = .{ \"bin/s\", \"{port}\" } },", error.BadServer },
        .{ node_fields ++ ".server = .{ .name = \"s\", .argv = .{ \"bin/s\", \"{port}\" }, .ready_path = \"test/\" },", error.BadServer },
        .{ node_fields ++ ".server = .{ .name = \"s\", .argv = .{ \"bin/s\", \"{port}\" }, .ready_s = 0 },", error.BadServer },
        .{ node_fields ++ ".server = .{ .name = \"s\", .argv = .{ \"bin/s\", \"{port}\" }, .host = \"Local Host\" },", error.BadServer },
        .{ node_fields ++ server_fields ++ ".overlay = .{.{ .prefix = \"crane/x\", .dir = \"tests/frameworks/todomvc\" }},", error.ServerWithOverlay },
        // Pins checked as every other pin is.
        .{ ".node = .{ .version = \"24.22.3\", .archives = .{.{ .platform = \"linux-x64\", .url = \"http://nodejs.org/x.tar.gz\", .sha256 = \"061ec3e3062115705b56b51fa9cc330ab50d34b6969387d4e4b1a50c6809acc2\" }} },", error.BadUrl },
        .{ ".node = .{ .version = \"24.22.3\", .archives = .{.{ .platform = \"linux-x64\", .url = \"https://nodejs.org/x.tar.gz\", .sha256 = \"061ec\" }} },", error.BadSha256 },
        .{ ".node = .{ .version = \"v24\", .archives = .{.{ .platform = \"linux-x64\", .url = \"https://nodejs.org/x.tar.gz\", .sha256 = \"061ec3e3062115705b56b51fa9cc330ab50d34b6969387d4e4b1a50c6809acc2\" }} },", error.BadName },
        .{ ".node = .{ .version = \"24.22.3\", .archives = .{} },", error.BadName },
        .{ node_fields ++ ".npm = .{ .lockfile_sha256 = \"b0b0\" },", error.BadSha256 },
        .{ node_fields ++ ".npm = .{ .lockfile_sha256 = \"b0b0be0c8e8c4ba6a3a23c4ac7a1178a0dd7fb7fa14f22ed66404df5e52a991b\", .scripts = .{\"rm -rf\"} },", error.BadName },
    };
    for (cases) |c| {
        var f: Failure = .{};
        try testing.expectError(c[1], parse(testing.allocator, a, try withFields(a, c[0]), &f));
        try testing.expectEqualStrings("jquery-qunit", f.suite);
    }
}

test "validate: a page path may name a directory (jquery-test-runner opens test/?module=<m>)" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const dir_page = try std.mem.replaceOwned(u8, a, sample, "test/index.html?module=basic", "test/?module=basic");
    var f: Failure = .{};
    const m = try parse(testing.allocator, a, try a.dupeSentinel(u8, dir_page, 0), &f);
    try testing.expectEqualStrings("test/?module=basic", find(m, "jquery-qunit").?.pages[0].path);
    try testing.expectEqualStrings("test/index.html", try pageFile(a, "test/?module=basic"));
    try testing.expectEqualStrings("test/index.html", try pageFile(a, "test/index.html?module=basic"));
    for ([_][]const u8{ "test//?module=basic", "/test/", "../test/" }) |bad_path| {
        const bad = try std.mem.replaceOwned(u8, a, sample, "test/index.html?module=basic", bad_path);
        try testing.expectError(error.BadPath, parse(testing.allocator, a, try a.dupeSentinel(u8, bad, 0), &f));
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
