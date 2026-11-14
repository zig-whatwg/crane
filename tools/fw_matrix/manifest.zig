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
    /// Path and query below the tree's root, as the project opens it ("" is
    /// the server's root: web-test-runner's test pages are "/?wtr-test-file=").
    path: []const u8,
    /// QUnit: the module the page selects (`?module=`), whose exclusions
    /// it applies; null for a page that runs everything.
    module: ?[]const u8 = null,
    /// The project's own Bazel target that serves the page (its server's
    /// "{target}"): Angular's web-test-runner debug targets, one per page.
    target: ?[]const u8 = null,
};

pub const BinaryPin = struct {
    platform: []const u8,
    sha256: []const u8,

    pub fn find(pins: []const BinaryPin, platform: []const u8) ?BinaryPin {
        for (pins) |p| if (std.mem.eql(u8, p.platform, platform)) return p;
        return null;
    }
};

/// Bazel, for a suite whose project builds and serves its browser tests
/// with it (Angular): bazelisk pinned per platform, and the Bazel release
/// the project's .bazelversion names, checked by bazelisk against its
/// sha256 (BAZELISK_VERIFY_SHA256). Bazel's own downloads are the project's
/// pins (MODULE.bazel.lock). Its output root is under the frameworks
/// directory, so that one deletion removes every byte it made.
pub const Bazel = struct {
    bazelisk_version: []const u8,
    bazelisk: []const NodeArchive,
    /// The .bazelversion the tree names.
    version: []const u8,
    /// The Bazel binary's sha256 per platform (Node's platform names).
    binaries: []const BinaryPin,
    /// `bazel build --jobs` in fetch.
    jobs: u32 = 6,
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
    bazel: ?Bazel = null,
    /// The project's own test server; null: the harness's static server.
    /// With "{target}" in its argv it serves one page: a server per page,
    /// started for it with the page's `target`.
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
    /// A tree several suites share, by its directory name below the
    /// frameworks directory; null: the suite's own, "<id>-<version>". Set
    /// only by the `todomvc` block's expansion.
    tree: ?[]const u8 = null,
    /// The TodoMVC app a suite checks; set only by the expansion.
    app: ?App = null,
    /// What a reader of the suite's row must know to read its numbers (how
    /// its tests are classified, what does not run and why); shown on its
    /// row and its page.
    note: ?[]const u8 = null,
};

/// One app of TodoMVC (the report's second section).
pub const App = struct {
    /// Its directory below examples/, which is also the name TodoMVC's app
    /// spec keys its tables by and the port's `?framework=` ("react").
    id: []const u8,
    /// todomvc.com's name for it ("React", "Vue.js").
    title: []const u8,
    /// Its folder below examples/ as todomvc.com links it ("react/dist"):
    /// the build the port opens (`&folder=`).
    folder: []const u8,
    /// The framework's version the app's files state (its package-lock.json,
    /// or the framework file's own header); null where they state none.
    version: ?[]const u8 = null,
    /// examples/<id>/ as one sha256 (fetch.dirHash), checked at every
    /// fetch: the pin of the app's build. Required for a served app.
    sha256: ?[]const u8 = null,
    /// TodoMVC's own runner skips the app (tests/excluded.js): its reason,
    /// shown beside the row. The app is run all the same.
    skipped_by_todomvc: ?[]const u8 = null,
    /// The app cannot be served, and why: it gets a row saying so and no
    /// suite.
    not_served: ?[]const u8 = null,
};

/// TodoMVC (the user, 2026-11-14: "We should report on as many frameworks
/// for TODOMVC as the actual TODOMVC site"): every app todomvc.com lists,
/// each the unmodified build committed in tastejs/todomvc, checked by
/// Crane's port of the app spec. `parse` makes a suite of kind
/// `.todomvc_port` per served app, all sharing one tree.
pub const TodoMvc = struct {
    repository: []const u8,
    commit: []const u8,
    licence: []const u8,
    runner: []const u8,
    reader: exclusions.Reader,
    source: Archive,
    dependencies: []const Dependency = &.{},
    overlay: []const Overlay = &.{},
    /// The port's page below the tree ("crane/todomvc/index.html").
    page: []const u8,
    excluded: []const u8,
    page_budget_s: u32 = 900,
    page_stall_s: u32 = 150,
    apps: []const App,

    /// The shared tree's directory: "todomvc-<first 12 of the commit>".
    pub fn treeDir(t: TodoMvc, arena: Allocator) ![]const u8 {
        return std.fmt.allocPrint(arena, "todomvc-{s}", .{t.commit[0..@min(12, t.commit.len)]});
    }
};

/// A framework's own browser tests that do not run in Crane, and why: a row
/// of the matrix's first section, so that a framework whose own tests cannot
/// run is never missing from it (lane fw1 b5: per framework, what runs and
/// what does not, with why).
pub const OwnSuiteNotRun = struct {
    /// What the project calls them ("e2e", "runtime-browser samples").
    name: []const u8,
    /// The release read.
    version: []const u8,
    repository: []const u8,
    tag: []const u8,
    /// How the project runs them ("Playwright on Chromium").
    runner: []const u8,
    /// How many tests, read from the source at the tag; null when not counted.
    tests: ?u32 = null,
    /// Why Crane does not run them.
    why: []const u8,
    /// The browser-automation protocol their runner drives the browser
    /// through, which Crane does not speak yet (the user, 2026-11-14: suites
    /// needing CDP or WebDriver BiDi wait until after Crane 0.1); null for
    /// tests not run for another reason (an application's tests, not the
    /// framework's).
    waits_for: ?Protocol = null,
};

/// A browser-automation protocol a project's test runner needs.
pub const Protocol = enum {
    /// Playwright's Chromium, Vitest's cdp(): only CDP.
    cdp,
    /// Puppeteer: either.
    cdp_or_bidi,

    pub fn label(p: Protocol) []const u8 {
        return switch (p) {
            .cdp => "the Chrome DevTools Protocol (CDP)",
            .cdp_or_bidi => "CDP or WebDriver BiDi",
        };
    }

    /// The short name a table cell holds.
    pub fn short(p: Protocol) []const u8 {
        return switch (p) {
            .cdp => "CDP",
            .cdp_or_bidi => "CDP or WebDriver BiDi",
        };
    }
};

/// A framework waits when Crane runs none of its own suites and every own
/// suite it lists waits for a protocol (the report's second group of rows).
pub fn waits(m: Manifest, fw: Framework) bool {
    for (m.suites) |s| {
        if (s.kind == .project and std.mem.eql(u8, s.framework, fw.id)) return false;
    }
    if (fw.not_run.len == 0) return false;
    for (fw.not_run) |n| if (n.waits_for == null) return false;
    return true;
}

/// What a failure is, on the report: a gap in Crane, or an API only Chrome
/// ships that is no standard yet (the integrator, 2026-11-14: "keep it on
/// the page but under its own small heading ... so the main list is the
/// real Crane gaps").
pub const CauseKind = enum { crane_gap, chrome_only_api };

/// Which failures a cause covers: a test matches when every field given
/// matches it (`suite` and `page` exactly, the others as substrings of the
/// test's id or its first failing assertion); a page that stopped before its
/// tests ran matches a `suite` + `page` match, or one whose
/// `message_contains` is in the page's own message.
pub const Match = struct {
    suite: ?[]const u8 = null,
    page: ?[]const u8 = null,
    id_contains: ?[]const u8 = null,
    message_contains: ?[]const u8 = null,
};

/// One cause of the failures Crane has and Chrome does not (the report's
/// "What fails in Crane and passes in Chrome"), written by hand from the
/// failures' messages; the report counts what it covers from the journals,
/// drops a cause that covers nothing any more, and names every Crane-only
/// failure no cause covers.
pub const Cause = struct {
    /// What Crane lacks, as one line ("console.timeStamp() is missing").
    title: []const u8,
    kind: CauseKind = .crane_gap,
    covers: []const Match,
};

/// A framework of the matrix's first section, "The frameworks' own test
/// suites": its rows are its suites of kind `.project`, then its own suites
/// that do not run. TodoMVC apps are the second section's, whatever their
/// framework.
pub const Framework = struct {
    /// The `framework` of its suites ("react").
    id: []const u8,
    title: []const u8,
    not_run: []const OwnSuiteNotRun = &.{},
};

pub const Manifest = struct {
    /// The first section's frameworks, in the order shown; empty in a
    /// manifest that only runs suites.
    frameworks: []const Framework = &.{},
    suites: []const Suite,
    /// After `parse`, its served apps are suites too (at the end of
    /// `suites`, in the block's order).
    todomvc: ?TodoMvc = null,
    /// The causes of Crane-only failures, in the order shown.
    causes: []const Cause = &.{},
};

pub const Error = error{ OutOfMemory, ParseZon, BadName, BadSha256, BadPath, BadUrl, DuplicatePage, DuplicateSuite, NoPages, LiveLoadsNotAllowed, BadIntegrity, OverlappingOverlay, NpmWithoutNode, ServerWithoutNode, BadServer, ServerWithoutPort, ServerWithOverlay, DuplicateFramework, UnknownFramework, FrameworkWithoutSuite, BadNotRun, DuplicateApp, AppWithoutPin, BadApp, PageWithoutTarget, BadCause };

/// The text a server argument holds where the harness's port goes.
pub const port_placeholder = "{port}";

pub const Failure = struct {
    suite: []const u8 = "",
    what: []const u8 = "",
    diagnostics: std.zon.parse.Diagnostics = .{ .errors = &.{} },
};

pub fn parse(gpa: Allocator, arena: Allocator, source: [:0]const u8, failure: *Failure) Error!Manifest {
    var m = try std.zon.parse.fromSlice(Manifest, .{ .gpa = gpa, .arena = arena, .source = source, .diagnostics = &failure.diagnostics });
    if (m.todomvc) |t| {
        try validateTodoMvc(t, failure);
        m.suites = try expandTodoMvc(arena, m.suites, t);
    }
    try validate(m, failure);
    return m;
}

/// The served apps of the TodoMVC block as suites, after `suites`: one page
/// each, the port opened on the app's folder as todomvc.com links it.
pub fn expandTodoMvc(arena: Allocator, suites: []const Suite, t: TodoMvc) Error![]const Suite {
    var out: std.ArrayList(Suite) = .empty;
    try out.appendSlice(arena, suites);
    const tree = try t.treeDir(arena);
    for (t.apps) |app| {
        if (app.not_served != null) continue;
        const pages = try arena.alloc(Page, 1);
        pages[0] = .{ .id = "todomvc", .path = try std.fmt.allocPrint(arena, "{s}?framework={s}&folder={s}", .{ t.page, app.id, app.folder }) };
        try out.append(arena, .{
            .id = try std.fmt.allocPrint(arena, "{s}-todomvc", .{app.id}),
            .framework = app.id,
            .title = app.title,
            // The app's framework version where its files state one; else
            // the commit its build is pinned by.
            .version = app.version orelse t.commit[0..@min(12, t.commit.len)],
            .kind = .todomvc_port,
            .repository = t.repository,
            .tag = try std.fmt.allocPrint(arena, "examples/{s}", .{app.folder}),
            .commit = t.commit,
            .licence = t.licence,
            .runner = t.runner,
            .reader = t.reader,
            .source = t.source,
            .dependencies = t.dependencies,
            .overlay = t.overlay,
            .pages = pages,
            .excluded = t.excluded,
            .page_budget_s = t.page_budget_s,
            .page_stall_s = t.page_stall_s,
            .tree = tree,
            .app = app,
        });
    }
    return out.items;
}

fn validateTodoMvc(t: TodoMvc, failure: *Failure) Error!void {
    failure.suite = "todomvc";
    failure.what = "page";
    if (!isRelativePath(t.page) or std.mem.indexOfScalar(u8, t.page, '?') != null) return error.BadPath;
    failure.what = "commit";
    if (t.commit.len < 12) return error.BadName;
    for (t.apps, 0..) |app, i| {
        failure.what = app.id;
        if (!isName(app.id) or app.title.len == 0) return error.BadName;
        for (t.apps[0..i]) |o| if (std.mem.eql(u8, o.id, app.id)) return error.DuplicateApp;
        // The folder is the app's, below its own directory.
        if (!isRelativePath(app.folder) or !underPrefix(app.folder, app.id)) return error.BadPath;
        for (app.folder) |c| if (c == '&' or c == '?' or c == '#' or c == '%' or c == ' ') return error.BadPath;
        if (app.version) |v| if (!isName(v)) return error.BadName;
        if (app.not_served) |why| {
            if (why.len == 0 or app.sha256 != null) return error.BadApp;
        } else {
            const h = app.sha256 orelse return error.AppWithoutPin;
            if (!journal.isSha256(h)) return error.BadSha256;
        }
        if (app.skipped_by_todomvc) |why| if (why.len == 0) return error.BadApp;
    }
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
    // The server's root itself.
    if (path_part.len == 0) return true;
    const trimmed = if (std.mem.endsWith(u8, path_part, "/")) path_part[0 .. path_part.len - 1] else path_part;
    return isRelativePath(trimmed);
}

/// The text a server argument holds where the page's Bazel target goes, and
/// the argument the fetched Bazel (bazelisk and its output root) replaces.
pub const target_placeholder = "{target}";
pub const bazel_placeholder = "{bazel}";

/// The server serves one page: its argv names the page's target.
pub fn serverPerPage(s: ExternalServer) bool {
    for (s.argv) |arg| if (std.mem.indexOf(u8, arg, target_placeholder) != null) return true;
    return false;
}

/// A Bazel label of the tree's own ("//packages/core/test:test_web_debug").
fn isLabel(s: []const u8) bool {
    if (!std.mem.startsWith(u8, s, "//")) return false;
    const colon = std.mem.indexOfScalar(u8, s, ':') orelse return false;
    if (colon + 1 >= s.len) return false;
    for (s[2..]) |c| if (!(std.ascii.isAlphanumeric(c) or c == '/' or c == ':' or c == '_' or c == '-' or c == '.')) return false;
    return isRelativePath(s[2..colon]);
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

fn validateServer(s: ExternalServer, bazel: bool, failure: *Failure) Error!void {
    failure.what = "server";
    if (s.name.len == 0 or s.argv.len == 0) return error.BadServer;
    // The tree's own command, by its path below the tree - or the fetched
    // Bazel, which runs the tree's own target.
    if (std.mem.eql(u8, s.argv[0], bazel_placeholder)) {
        if (!bazel) return error.BadServer;
    } else if (!isRelativePath(s.argv[0]) or std.mem.indexOfScalar(u8, s.argv[0], '/') == null) return error.BadServer;
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
        if (f.bazel) |bz| {
            failure.what = "bazel";
            if (!isVersion(bz.bazelisk_version) or !isVersion(bz.version) or bz.bazelisk.len == 0 or bz.binaries.len == 0 or bz.jobs == 0) return error.BadName;
            for (bz.bazelisk) |a| {
                if (!isName(a.platform)) return error.BadName;
                if (!isHttps(a.url)) return error.BadUrl;
                if (!journal.isSha256(a.sha256)) return error.BadSha256;
            }
            for (bz.binaries) |a| if (!journal.isSha256(a.sha256) or !isName(a.platform)) return error.BadSha256;
        }
        if (f.server) |s| {
            failure.what = "server";
            // Its runtime: Node, or Bazel (whose own Node runs the target).
            if (f.node == null and f.bazel == null) return error.ServerWithoutNode;
            // The project's server serves the tree alone: an overlay is the
            // harness's static server's.
            if (f.overlay.len > 0) return error.ServerWithOverlay;
            try validateServer(s, f.bazel != null, failure);
            // A server per page: every page names its target.
            var per_page = false;
            for (s.argv) |arg| per_page = per_page or std.mem.indexOf(u8, arg, target_placeholder) != null;
            for (f.pages) |p| {
                failure.what = p.id;
                if (per_page) {
                    const t = p.target orelse return error.PageWithoutTarget;
                    if (!isLabel(t)) return error.BadPath;
                } else if (p.target != null) return error.BadServer;
            }
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
    try validateFrameworks(m, failure);
    try validateCauses(m, failure);
    failure.* = .{ .diagnostics = failure.diagnostics };
}

/// Every cause has a title and covers something; every match names at
/// least one field, a suite the manifest has, and a page only within its
/// suite.
fn validateCauses(m: Manifest, failure: *Failure) Error!void {
    for (m.causes) |c| {
        failure.suite = "causes";
        failure.what = c.title;
        if (c.title.len == 0 or c.covers.len == 0) return error.BadCause;
        for (c.covers) |match| {
            if (match.suite == null and match.page == null and match.id_contains == null and match.message_contains == null) return error.BadCause;
            if (match.page != null and match.suite == null) return error.BadCause;
            const sid = match.suite orelse continue;
            const s = find(m, sid) orelse return error.BadCause;
            const pid = match.page orelse continue;
            for (s.pages) |p| {
                if (std.mem.eql(u8, p.id, pid)) break;
            } else return error.BadCause;
        }
    }
}

/// The first section: each framework once; each project suite under a
/// listed framework; each framework shows something - a suite of its own
/// or the own suites it does not run, with why.
fn validateFrameworks(m: Manifest, failure: *Failure) Error!void {
    if (m.frameworks.len == 0) return;
    for (m.frameworks, 0..) |fw, i| {
        failure.suite = fw.id;
        failure.what = "framework";
        if (!isName(fw.id) or fw.title.len == 0) return error.BadName;
        for (m.frameworks[0..i]) |o| if (std.mem.eql(u8, o.id, fw.id)) return error.DuplicateFramework;
        var has_suite = false;
        for (m.suites) |s| {
            if (s.kind == .project and std.mem.eql(u8, s.framework, fw.id)) has_suite = true;
        }
        if (!has_suite and fw.not_run.len == 0) return error.FrameworkWithoutSuite;
        for (fw.not_run) |n| {
            failure.what = n.name;
            if (n.name.len == 0 or n.runner.len == 0 or n.why.len == 0 or n.tag.len == 0) return error.BadNotRun;
            if (!isName(n.version)) return error.BadName;
            if (!isHttps(n.repository)) return error.BadUrl;
        }
    }
    for (m.suites) |s| {
        if (s.kind != .project) continue;
        failure.suite = s.id;
        failure.what = "framework";
        for (m.frameworks) |fw| {
            if (std.mem.eql(u8, fw.id, s.framework)) break;
        } else return error.UnknownFramework;
    }
}

pub fn findFramework(m: Manifest, id: []const u8) ?Framework {
    for (m.frameworks) |fw| if (std.mem.eql(u8, fw.id, id)) return fw;
    return null;
}

pub fn find(m: Manifest, id: []const u8) ?Suite {
    for (m.suites) |f| if (std.mem.eql(u8, f.id, id)) return f;
    return null;
}

/// The suite's tree below the frameworks directory: "<id>-<version>", or
/// the tree it shares.
pub fn treeName(arena: Allocator, f: Suite) ![]const u8 {
    if (f.tree) |t| return arena.dupe(u8, t);
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

const todomvc_block =
    \\    .todomvc = .{
    \\        .repository = "https://github.com/tastejs/todomvc",
    \\        .commit = "ff43b02e59dfa604386bb382034b2cd07c2bcd8a",
    \\        .licence = "MIT",
    \\        .runner = "QUnit 2.24.2",
    \\        .reader = .qunit,
    \\        .source = .{ .url = "https://codeload.github.com/tastejs/todomvc/tar.gz/ff43b02e59dfa604386bb382034b2cd07c2bcd8a", .sha256 = "22fd7c5251b636773561cc0ab606896f48c8dbcad80e79b427989bfc0e134718" },
    \\        .overlay = .{.{ .prefix = "crane/todomvc", .dir = "tests/frameworks/todomvc" }},
    \\        .page = "crane/todomvc/index.html",
    \\        .excluded = "todomvc-port.txt",
    \\        .page_budget_s = 300,
    \\        .apps = .{
    \\            .{ .id = "react", .title = "React", .folder = "react/dist", .version = "19.2.5", .sha256 = "1111111111111111111111111111111111111111111111111111111111111111" },
    \\            .{ .id = "javascript-es5", .title = "JavaScript ES5", .folder = "javascript-es5/dist", .sha256 = "2222222222222222222222222222222222222222222222222222222222222222" },
    \\            .{ .id = "gwt", .title = "GWT", .folder = "gwt", .sha256 = "3333333333333333333333333333333333333333333333333333333333333333", .skipped_by_todomvc = "deviates from the specification" },
    \\            .{ .id = "somajs", .title = "soma.js", .folder = "somajs", .not_served = "404 on todomvc.com; not in the repository" },
    \\        },
    \\    },
    \\
;

fn withTodoMvc(a: Allocator, block: []const u8) ![:0]const u8 {
    const text = try std.mem.replaceOwned(u8, a, sample, ".{\n    .suites", try std.fmt.allocPrint(a, ".{{\n{s}    .suites", .{block}));
    return a.dupeSentinel(u8, text, 0);
}

test "todomvc: a suite per served app, sharing one tree; the app spec's page opened on the app's folder" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var f: Failure = .{};
    const m = try parse(testing.allocator, a, try withTodoMvc(a, todomvc_block), &f);
    // jQuery's suite, then three apps: soma.js is not served, so no suite.
    try testing.expectEqual(@as(usize, 4), m.suites.len);
    try testing.expect(find(m, "somajs-todomvc") == null);
    const react = find(m, "react-todomvc").?;
    try testing.expectEqual(journal.SuiteKind.todomvc_port, react.kind);
    try testing.expectEqualStrings("react", react.framework);
    try testing.expectEqualStrings("19.2.5", react.version);
    try testing.expectEqualStrings("examples/react/dist", react.tag);
    try testing.expectEqualStrings("crane/todomvc/index.html?framework=react&folder=react/dist", react.pages[0].path);
    try testing.expectEqualStrings("todomvc", react.pages[0].id);
    try testing.expectEqualStrings("tests/frameworks/todomvc", react.overlay[0].dir);
    try testing.expectEqual(@as(u32, 300), react.page_budget_s);
    // One tree for every app, named by the commit.
    try testing.expectEqualStrings("todomvc-ff43b02e59df", try treeName(a, react));
    try testing.expectEqualStrings("todomvc-ff43b02e59df", try treeName(a, find(m, "gwt-todomvc").?));
    // No version stated: the commit stands for it.
    try testing.expectEqualStrings("ff43b02e59df", find(m, "javascript-es5-todomvc").?.version);
    try testing.expectEqualStrings("deviates from the specification", find(m, "gwt-todomvc").?.app.?.skipped_by_todomvc.?);
    try testing.expectEqualStrings("jquery-qunit-4.0.0", try treeName(a, find(m, "jquery-qunit").?));

    const cases = [_]struct { []const u8, []const u8, Error }{
        // A served app is pinned by its directory's hash.
        .{ ", .sha256 = \"1111111111111111111111111111111111111111111111111111111111111111\" }", " }", error.AppWithoutPin },
        .{ "\"1111111111111111111111111111111111111111111111111111111111111111\"", "\"11\"", error.BadSha256 },
        // Its folder is below its own directory, and safe in a URL.
        .{ ".folder = \"react/dist\"", ".folder = \"vue/dist\"", error.BadPath },
        .{ ".folder = \"react/dist\"", ".folder = \"react/../vue\"", error.BadPath },
        .{ ".folder = \"react/dist\"", ".folder = \"react/d&x=1\"", error.BadPath },
        .{ ".id = \"gwt\"", ".id = \"react\"", error.DuplicateApp },
        // An app that cannot be served says why, and has no pin.
        .{ ".not_served = \"404 on todomvc.com; not in the repository\"", ".not_served = \"\"", error.BadApp },
        .{ ".folder = \"somajs\",", ".folder = \"somajs\", .sha256 = \"1111111111111111111111111111111111111111111111111111111111111111\",", error.BadApp },
    };
    for (cases) |c| {
        const block = try std.mem.replaceOwned(u8, a, todomvc_block, c[0], c[1]);
        try testing.expect(!std.mem.eql(u8, block, todomvc_block));
        var f2: Failure = .{};
        try testing.expectError(c[2], parse(testing.allocator, a, try withTodoMvc(a, block), &f2));
    }
}

const bazel_fields =
    \\.bazel = .{ .bazelisk_version = "1.30.0", .bazelisk = .{.{ .platform = "darwin-arm64", .url = "https://github.com/bazelbuild/bazelisk/releases/download/v1.30.0/bazelisk-darwin-arm64", .sha256 = "555d2ff912ccd336d0060bdb5251ef2f62629c6f8fbadb59005a45d5625793ec" }}, .version = "8.8.2", .binaries = .{.{ .platform = "darwin-arm64", .sha256 = "1111111111111111111111111111111111111111111111111111111111111111" }} },
    \\.server = .{ .name = "web-test-runner (manual mode)", .argv = .{ "{bazel}", "run", "{target}", "--", "--port", "{port}" } },
;

test "a Bazel suite: its own debug targets, a server per page, each page naming its target" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const pages_from = ".pages = .{ .{ .id = \"basic\", .path = \"test/index.html?module=basic\", .module = \"basic\" } },";
    const pages_to = ".pages = .{ .{ .id = \"common-http\", .path = \"?wtr-test-file=%2Fpackages%2Fcommon%2Fhttp%2Ftest%2Ftest_web_bundle.spec.js%3Fwtr-manual-session%3Dtrue\", .target = \"//packages/common/http/test:test_web_debug\" } },";
    const text = try std.mem.replaceOwned(u8, a, try withFields(a, bazel_fields), pages_from, pages_to);
    var f: Failure = .{};
    const m = try parse(testing.allocator, a, try a.dupeSentinel(u8, text, 0), &f);
    const s = find(m, "jquery-qunit").?;
    try testing.expect(serverPerPage(s.server.?));
    try testing.expectEqualStrings("//packages/common/http/test:test_web_debug", s.pages[0].target.?);
    try testing.expectEqualStrings("8.8.2", s.bazel.?.version);
    // The server's root is a page path ("/?wtr-test-file=...").
    try testing.expectEqual(@as(u32, 6), s.bazel.?.jobs);

    const cases = [_]struct { []const u8, []const u8, Error }{
        // A page of a per-page server without its target.
        .{ ", .target = \"//packages/common/http/test:test_web_debug\"", "", error.PageWithoutTarget },
        // A target that is not a label of the tree.
        .{ "\"//packages/common/http/test:test_web_debug\"", "\"packages/x\"", error.BadPath },
        .{ "\"//packages/common/http/test:test_web_debug\"", "\"//../x:y\"", error.BadPath },
    };
    for (cases) |c| {
        const bad = try std.mem.replaceOwned(u8, a, text, c[0], c[1]);
        try testing.expect(!std.mem.eql(u8, bad, text));
        try testing.expectError(c[2], parse(testing.allocator, a, try a.dupeSentinel(u8, bad, 0), &f));
    }
    // "{bazel}" needs a fetched Bazel.
    const no_bazel = try std.mem.replaceOwned(u8, a, text, bazel_fields[0 .. std.mem.indexOf(u8, bazel_fields, "\n.server").? + 1], "");
    try testing.expectError(error.ServerWithoutNode, parse(testing.allocator, a, try a.dupeSentinel(u8, no_bazel, 0), &f));
}

test "frameworks: the first section's list; each project suite under one, each framework with a suite or a reason" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const not_run =
        \\.not_run = .{.{ .name = "e2e", .version = "19.3.1", .repository = "https://github.com/facebook/react", .tag = "v19.3.1", .runner = "Playwright on Chromium", .tests = 19, .why = "w" }}
    ;
    const with_frameworks = try std.fmt.allocPrint(a, ".{{ .frameworks = .{{ .{{ .id = \"jquery\", .title = \"jQuery\" }}, .{{ .id = \"react\", .title = \"React\", {s} }} }},", .{not_run});
    const text = try std.mem.replaceOwned(u8, a, sample, ".{\n    .suites", try std.fmt.allocPrint(a, "{s}\n    .suites", .{with_frameworks}));
    var f: Failure = .{};
    const m = try parse(testing.allocator, a, try a.dupeSentinel(u8, text, 0), &f);
    try testing.expectEqual(@as(usize, 2), m.frameworks.len);
    const react = findFramework(m, "react").?;
    try testing.expectEqual(@as(?u32, 19), react.not_run[0].tests);
    try testing.expectEqual(@as(usize, 0), findFramework(m, "jquery").?.not_run.len);
    // None at all: a manifest that only runs suites.
    try testing.expectEqual(@as(usize, 0), (try parse(testing.allocator, a, sample, &f)).frameworks.len);

    const cases = [_]struct { []const u8, Error }{
        // jQuery's suite under no listed framework.
        .{ ".{ .frameworks = .{ .{ .id = \"htmx\", .title = \"htmx\", .not_run = .{.{ .name = \"n\", .version = \"1.0.0\", .repository = \"https://x\", .tag = \"t\", .runner = \"r\", .why = \"w\" }} } },", error.UnknownFramework },
        // A framework with nothing to show.
        .{ ".{ .frameworks = .{ .{ .id = \"jquery\", .title = \"jQuery\" }, .{ .id = \"vue\", .title = \"Vue\" } },", error.FrameworkWithoutSuite },
        .{ ".{ .frameworks = .{ .{ .id = \"jquery\", .title = \"jQuery\" }, .{ .id = \"jquery\", .title = \"jQuery\" } },", error.DuplicateFramework },
        // A reason is required, and the repository is checked like a pin.
        .{ ".{ .frameworks = .{ .{ .id = \"jquery\", .title = \"jQuery\", .not_run = .{.{ .name = \"n\", .version = \"1.0.0\", .repository = \"https://x\", .tag = \"t\", .runner = \"r\", .why = \"\" }} } },", error.BadNotRun },
        .{ ".{ .frameworks = .{ .{ .id = \"jquery\", .title = \"jQuery\", .not_run = .{.{ .name = \"n\", .version = \"1.0.0\", .repository = \"http://x\", .tag = \"t\", .runner = \"r\", .why = \"w\" }} } },", error.BadUrl },
    };
    for (cases) |c| {
        const bad = try std.mem.replaceOwned(u8, a, sample, ".{\n    .suites", try std.fmt.allocPrint(a, "{s}\n    .suites", .{c[0]}));
        try testing.expectError(c[1], parse(testing.allocator, a, try a.dupeSentinel(u8, bad, 0), &f));
    }
}

test "frameworks: an own suite that waits names the protocol it waits for; one that does not, none" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const frameworks =
        \\.{ .frameworks = .{ .{ .id = "jquery", .title = "jQuery", .not_run = .{.{ .name = "docs", .version = "4.0.0", .repository = "https://x", .tag = "t", .runner = "r", .why = "an app" }} },
        \\    .{ .id = "vue", .title = "Vue", .not_run = .{
        \\        .{ .name = "e2e", .version = "3.5.45", .repository = "https://x", .tag = "t", .runner = "Puppeteer", .tests = 36, .why = "w", .waits_for = .cdp_or_bidi },
        \\        .{ .name = "e2e-browser", .version = "3.5.45", .repository = "https://x", .tag = "t", .runner = "Playwright", .tests = 84, .why = "w", .waits_for = .cdp },
        \\    } } },
    ;
    const text = try std.mem.replaceOwned(u8, a, sample, ".{\n    .suites", try std.fmt.allocPrint(a, "{s}\n    .suites", .{frameworks}));
    var f: Failure = .{};
    const m = try parse(testing.allocator, a, try a.dupeSentinel(u8, text, 0), &f);
    const vue = findFramework(m, "vue").?;
    try testing.expectEqual(@as(?Protocol, .cdp_or_bidi), vue.not_run[0].waits_for);
    try testing.expectEqual(@as(?Protocol, .cdp), vue.not_run[1].waits_for);
    try testing.expectEqual(@as(?Protocol, null), findFramework(m, "jquery").?.not_run[0].waits_for);
    // A framework waits when it runs nothing and every own suite of it waits.
    try testing.expect(waits(m, vue));
    try testing.expect(!waits(m, findFramework(m, "jquery").?));
    try testing.expectEqualStrings("the Chrome DevTools Protocol (CDP)", Protocol.label(.cdp));
}

test "causes: each covers failures by suite, page, test name or message; checked against the suites" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const causes =
        \\.{ .causes = .{
        \\    .{ .title = "console.timeStamp() is missing", .covers = .{.{ .suite = "jquery-qunit", .message_contains = "timeStamp() method does not exist" }} },
        \\    .{ .title = "navigator.modelContext (WebMCP)", .kind = .chrome_only_api, .covers = .{ .{ .id_contains = "WebMcp" }, .{ .id_contains = "WebMCP" } } },
        \\    .{ .title = "A page stops", .covers = .{.{ .suite = "jquery-qunit", .page = "basic" }} },
        \\},
    ;
    const text = try std.mem.replaceOwned(u8, a, sample, ".{\n    .suites", try std.fmt.allocPrint(a, "{s}\n    .suites", .{causes}));
    var f: Failure = .{};
    const m = try parse(testing.allocator, a, try a.dupeSentinel(u8, text, 0), &f);
    try testing.expectEqual(@as(usize, 3), m.causes.len);
    try testing.expectEqual(CauseKind.crane_gap, m.causes[0].kind);
    try testing.expectEqual(CauseKind.chrome_only_api, m.causes[1].kind);

    const bad = [_][]const u8{
        // No title; nothing covered; a match with no field; a suite or page the manifest lacks.
        \\.{ .causes = .{.{ .title = "", .covers = .{.{ .id_contains = "x" }} }},
        ,
        \\.{ .causes = .{.{ .title = "t", .covers = .{} }},
        ,
        \\.{ .causes = .{.{ .title = "t", .covers = .{.{}} }},
        ,
        \\.{ .causes = .{.{ .title = "t", .covers = .{.{ .suite = "nope", .id_contains = "x" }} }},
        ,
        \\.{ .causes = .{.{ .title = "t", .covers = .{.{ .suite = "jquery-qunit", .page = "nope" }} }},
        ,
        \\.{ .causes = .{.{ .title = "t", .covers = .{.{ .page = "basic" }} }},
        ,
    };
    for (bad) |c| {
        const t = try std.mem.replaceOwned(u8, a, sample, ".{\n    .suites", try std.fmt.allocPrint(a, "{s}\n    .suites", .{c}));
        try testing.expectError(error.BadCause, parse(testing.allocator, a, try a.dupeSentinel(u8, t, 0), &f));
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
