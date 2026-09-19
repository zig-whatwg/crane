//! WPT Server Manager
//!
//! This module manages the lifecycle of the `wpt serve` Python server.
//! Uses a lockfile to track the server PID and port.
//!
//! ## Usage
//!
//! ```zig
//! var server = try WptServer.init(allocator, "tests/wpt");
//! defer server.deinit();
//!
//! try server.start();
//! // Server is now running at http://localhost:8000
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const posix = std.posix;
const test_parser = @import("test_parser.zig");

/// Lockfile name stored in WPT root
const LOCKFILE_NAME = ".wpt_serve.lock";

/// The host every test URL is built from.
///
/// Not `localhost`. WPT generates its own certificate authority under
/// `tools/certs/`, and the leaf certificate's subject alternative names cover
/// `web-platform.test` and its subdomains only — a TLS connection to
/// `localhost:8443` cannot verify against it at any price short of disabling
/// verification. Using the same host for plain HTTP keeps the document origin
/// equal to the origin the script loader already builds subresource URLs from.
///
/// WPT's own setup instructions have this in `/etc/hosts` pointing at 127.0.0.1.
pub const WPT_HOST = "web-platform.test";

/// Does this test have to be served over TLS?
///
/// The marker is a component of the *filename*, per WPT's naming convention:
/// `foo.https.html`, `foo.https.any.js`, `foo.https.window.js`. Matching against
/// the whole path would sweep in every test under a directory that happened to
/// contain the string.
pub fn isHttpsTest(test_path: []const u8) bool {
    return std.mem.indexOf(u8, std.fs.path.basename(test_path), ".https.") != null;
}

/// The origin of an absolute URL: scheme, host and port, no trailing slash.
///
/// Same-origin checks for blob URLs and worker scripts compare against this
/// string, so a TLS test handed the plain-HTTP origin fails them for a reason
/// that has nothing to do with the code under test. A slice of the input, not a
/// copy; null for anything that is not an absolute URL.
pub fn originOfUrl(url: []const u8) ?[]const u8 {
    const sep = std.mem.indexOf(u8, url, "://") orelse return null;
    const after_scheme = sep + 3;
    // The authority ends at the first delimiter that can follow it.
    const rest = url[after_scheme..];
    const end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    return url[0 .. after_scheme + end];
}

/// WPT Server manager
pub const WptServer = struct {
    allocator: Allocator,
    /// WPT root directory
    wpt_root: []const u8,
    /// Server port (HTTP)
    port: u16 = 8000,
    /// Server port (TLS). `wpt serve` binds this alongside the HTTP one; it is
    /// not optional and not separately startable.
    https_port: u16 = 8443,
    /// PID of the server process (from lockfile or spawned)
    pid: ?posix.pid_t = null,
    /// Whether we spawned the server (vs found existing)
    we_spawned: bool = false,

    /// Initialize the WPT server manager
    pub fn init(allocator: Allocator, wpt_root: []const u8) !*WptServer {
        const server = try allocator.create(WptServer);
        server.* = WptServer{
            .allocator = allocator,
            .wpt_root = try allocator.dupe(u8, wpt_root),
        };
        return server;
    }

    /// Cleanup - kills server if we spawned it
    pub fn deinit(self: *WptServer) void {
        if (self.we_spawned and self.pid != null) {
            self.stop();
        }
        self.allocator.free(self.wpt_root);
        self.allocator.destroy(self);
    }

    /// Get lockfile path
    fn getLockfilePath(self: *WptServer) ![]u8 {
        return std.fs.path.join(self.allocator, &.{ self.wpt_root, LOCKFILE_NAME });
    }

    /// Start the WPT server
    ///
    /// First checks if a server is already running (via lockfile).
    /// If not, spawns a new server and writes the lockfile.
    pub fn start(self: *WptServer) !void {
        // Check for existing server
        if (try self.checkExistingServer()) {
            return; // Server already running
        }

        // Spawn new server
        try self.spawnServer();
    }

    /// Check if an existing server is running via lockfile
    fn checkExistingServer(self: *WptServer) !bool {
        const lockfile_path = try self.getLockfilePath();
        defer self.allocator.free(lockfile_path);

        const file = std.fs.cwd().openFile(lockfile_path, .{}) catch |err| {
            if (err == error.FileNotFound) return false;
            return err;
        };
        defer file.close();

        // Read lockfile: "pid:port"
        var buf: [64]u8 = undefined;
        const bytes_read = try file.readAll(&buf);
        const content = buf[0..bytes_read];

        // Parse PID and port
        var iter = std.mem.splitScalar(u8, content, ':');
        const pid_str = iter.next() orelse return false;
        const port_str = iter.next() orelse return false;

        const pid = std.fmt.parseInt(posix.pid_t, std.mem.trim(u8, pid_str, &std.ascii.whitespace), 10) catch return false;
        const port = std.fmt.parseInt(u16, std.mem.trim(u8, port_str, &std.ascii.whitespace), 10) catch return false;

        // Check if process is still alive (signal 0 just checks existence)
        if (posix.kill(pid, 0)) {
            // Process exists, use it
            self.pid = pid;
            self.port = port;
            self.we_spawned = false;
            return true;
        } else |_| {
            // Process doesn't exist - stale lockfile, remove it
            std.fs.cwd().deleteFile(lockfile_path) catch {};
            return false;
        }
    }

    /// Spawn the wpt serve process
    fn spawnServer(self: *WptServer) !void {
        const argv = [_][]const u8{
            "python3",
            "wpt.py",
            "serve",
            "--config",
            "config.json",
        };

        var child = std.process.Child.init(&argv, self.allocator);
        child.cwd = self.wpt_root;

        // Ignore output to avoid noise
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        try child.spawn();

        self.pid = child.id;
        self.we_spawned = true;

        // Write lockfile
        try self.writeLockfile();

        // Wait for server to be ready (simple TCP check)
        try self.waitForReady();
    }

    /// Write the lockfile with PID and port
    fn writeLockfile(self: *WptServer) !void {
        const lockfile_path = try self.getLockfilePath();
        defer self.allocator.free(lockfile_path);

        const file = try std.fs.cwd().createFile(lockfile_path, .{});
        defer file.close();

        const content = try std.fmt.allocPrint(self.allocator, "{d}:{d}\n", .{ self.pid.?, self.port });
        defer self.allocator.free(content);
        try file.writeAll(content);
    }

    /// Remove the lockfile
    fn removeLockfile(self: *WptServer) void {
        const lockfile_path = self.getLockfilePath() catch return;
        defer self.allocator.free(lockfile_path);
        std.fs.cwd().deleteFile(lockfile_path) catch {};
    }

    /// Wait for server to become ready
    fn waitForReady(self: *WptServer) !void {
        const max_attempts = 100; // 10 seconds total
        const delay_ns: u64 = 100 * std.time.ns_per_ms;

        var attempt: usize = 0;
        while (attempt < max_attempts) : (attempt += 1) {
            if (self.isServerReady()) {
                return;
            }
            std.Thread.sleep(delay_ns);
        }

        return error.ServerStartTimeout;
    }

    /// Check if server is ready by attempting TCP connect
    fn isServerReady(self: *WptServer) bool {
        const address = std.net.Address.parseIp4("127.0.0.1", self.port) catch return false;
        const stream = std.net.tcpConnectToAddress(address) catch return false;
        stream.close();
        return true;
    }

    /// Stop the WPT server
    pub fn stop(self: *WptServer) void {
        if (self.pid) |pid| {
            // Send SIGTERM
            posix.kill(pid, posix.SIG.TERM) catch {};

            // Give it a moment to shutdown gracefully
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Force kill if still alive
            if (posix.kill(pid, 0)) {
                posix.kill(pid, posix.SIG.KILL) catch {};
            } else |_| {}
        }

        if (self.we_spawned) {
            self.removeLockfile();
        }

        self.pid = null;
        self.we_spawned = false;
    }

    /// Get the plain-HTTP base URL for the server, for display.
    ///
    /// Test URLs come from `buildTestUrl`, which picks the scheme per test.
    pub fn getBaseUrl(self: *WptServer, allocator: Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "http://{s}:{d}", .{ WPT_HOST, self.port });
    }

    /// The origin a given test's document will have once fetched.
    ///
    /// Same-origin checks for blob URLs and worker scripts compare against this,
    /// so it has to track the scheme and port the document actually came from.
    pub fn originFor(self: *WptServer, allocator: Allocator, test_path: []const u8) ![]u8 {
        return if (isHttpsTest(test_path))
            std.fmt.allocPrint(allocator, "https://{s}:{d}", .{ WPT_HOST, self.https_port })
        else
            std.fmt.allocPrint(allocator, "http://{s}:{d}", .{ WPT_HOST, self.port });
    }

    /// Build a test URL from a test path, context type and variant.
    ///
    /// For .any.js tests, the WPT server generates different HTML wrappers:
    /// - Window context: test.any.html (runs test directly in window)
    /// - Worker context: test.any.worker.html (uses fetch_tests_from_worker)
    ///
    /// A `.https.` test is routed to the TLS listener; see `isHttpsTest`.
    ///
    /// `variant` is one of the file's `<meta name="variant">` values, appended
    /// verbatim after the wrapper suffix because it already carries its own `?`
    /// or `#`. Empty means the file declares no variants, which is the common
    /// case and leaves the URL exactly as it was before variants existed.
    pub fn buildTestUrl(
        self: *WptServer,
        allocator: Allocator,
        test_path: []const u8,
        context: test_parser.GlobalType,
        variant: []const u8,
    ) ![]u8 {
        var url_path = test_path;
        var suffix: []const u8 = "";

        if (std.mem.endsWith(u8, test_path, ".any.js")) {
            url_path = test_path[0 .. test_path.len - 7];
            // Generate context-specific URL
            suffix = switch (context) {
                .worker => ".any.worker.html",
                .sharedworker => ".any.sharedworker.html",
                .serviceworker => ".any.serviceworker.html",
                else => ".any.html", // window and other contexts
            };
        } else if (std.mem.endsWith(u8, test_path, ".window.js")) {
            url_path = test_path[0 .. test_path.len - 10];
            suffix = ".window.html";
        } else if (std.mem.endsWith(u8, test_path, ".worker.js")) {
            url_path = test_path[0 .. test_path.len - 10];
            suffix = ".worker.html";
        }

        const https = isHttpsTest(test_path);
        return std.fmt.allocPrint(allocator, "{s}://{s}:{d}/{s}{s}{s}", .{
            if (https) "https" else "http",
            WPT_HOST,
            if (https) self.https_port else self.port,
            url_path,
            suffix,
            variant,
        });
    }
};

/// Write a lockfile naming `pid` into a scratch WPT root.
fn writeTestLockfile(dir: std.fs.Dir, pid: posix.pid_t) !void {
    var file = try dir.createFile(LOCKFILE_NAME, .{});
    defer file.close();
    var buf: [64]u8 = undefined;
    try file.writeAll(try std.fmt.bufPrint(&buf, "{d}:8000\n", .{pid}));
}

test "a live lockfile is adopted, not owned" {
    // Under --supervise the parent starts the server and every child finds it
    // this way. A child that thought it owned the server would SIGTERM it on
    // exit and leave the rest of the run with nothing to talk to.
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    try writeTestLockfile(tmp.dir, std.c.getpid());

    const server = try WptServer.init(allocator, root);
    defer server.deinit();

    try std.testing.expect(try server.checkExistingServer());
    try std.testing.expectEqual(std.c.getpid(), server.pid.?);
    try std.testing.expectEqual(@as(u16, 8000), server.port);
    try std.testing.expect(!server.we_spawned);

    // Still there: adopting must not consume the lockfile the owner wrote.
    try tmp.dir.access(LOCKFILE_NAME, .{});
}

test "a lockfile naming a dead process is cleared" {
    // A crashed run can leave its lockfile behind. Trusting it would point the
    // next run at a port nothing is listening on, and every test would fail
    // for a reason that has nothing to do with the browser.
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    // Above any pid_max, so kill() cannot find it and cannot ever be reused.
    try writeTestLockfile(tmp.dir, 2147483646);

    const server = try WptServer.init(allocator, root);
    defer server.deinit();

    try std.testing.expect(!try server.checkExistingServer());
    try std.testing.expect(server.pid == null);
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(LOCKFILE_NAME, .{}));
}

test "no lockfile means no server to adopt" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const server = try WptServer.init(allocator, root);
    defer server.deinit();

    try std.testing.expect(!try server.checkExistingServer());
    try std.testing.expect(server.pid == null);
}

test "WptServer.buildTestUrl" {
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    // Window context (default for .any.js)
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/url/url-constructor.any.html", url);
    }

    // Worker context generates .any.worker.html
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .worker, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/url/url-constructor.any.worker.html", url);
    }

    // Window context for another .any.js test
    {
        const url = try server.buildTestUrl(allocator, "encoding/api-basics.any.js", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/encoding/api-basics.any.html", url);
    }

    // HTML files ignore context (always use raw path)
    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/dom/nodes/Element-matches.html", url);
    }
}

test "buildTestUrl appends a variant verbatim" {
    // A variant carries its own leading `?` or `#` - WPT writes them as
    // `<meta name="variant" content="?include=file">` - so it is concatenated
    // rather than joined. Anything that normalised it here would build a URL
    // that is not the one MANIFEST.json lists.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const url = try server.buildTestUrl(allocator, "encoding/single-byte-decoder.html", .window, "?windows-1252");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "http://web-platform.test:8000/encoding/single-byte-decoder.html?windows-1252",
            url,
        );
    }

    // A fragment variant is passed through untouched, not turned into a query.
    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html", .window, "#target");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "http://web-platform.test:8000/dom/nodes/Element-matches.html#target",
            url,
        );
    }
}

test "buildTestUrl puts the variant after the generated wrapper suffix" {
    // The path `wpt serve` routes on is the wrapper - `x.any.worker.html` - and
    // the query is what the test reads back out of `location.search`. Appending
    // the variant before the suffix would ask for `x.any?q=1.worker.html` and
    // 404 every variant of every .any.js in the corpus.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .window, "?include=file");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "http://web-platform.test:8000/url/url-constructor.any.html?include=file",
            url,
        );
    }
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .worker, "?include=file");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "http://web-platform.test:8000/url/url-constructor.any.worker.html?include=file",
            url,
        );
    }
    {
        const url = try server.buildTestUrl(allocator, "html/dom/idlharness.https.window.js", .window, "?exclude=Node");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "https://web-platform.test:8443/html/dom/idlharness.https.window.html?exclude=Node",
            url,
        );
    }
}

test "buildTestUrl with an empty variant is byte-identical to no variant" {
    // Two thirds of the corpus declares no variant and is modelled as declaring
    // one empty one, so this is the path almost every test takes. It has to
    // produce exactly the URL it produced before variants existed.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    for ([_][]const u8{
        "dom/nodes/Element-matches.html",
        "url/url-constructor.any.js",
        "fetch/api/basic/keepalive.https.any.js",
    }) |path| {
        for ([_]test_parser.GlobalType{ .window, .worker }) |ctx| {
            const url = try server.buildTestUrl(allocator, path, ctx, "");
            defer allocator.free(url);
            try std.testing.expect(std.mem.indexOfScalar(u8, url, '?') == null);
            try std.testing.expect(std.mem.endsWith(u8, url, ".html"));
        }
    }
}

test "a variant does not leak into the document origin" {
    // Same-origin checks compare against `originFor`, which is derived from the
    // path alone. If the query ever reached the origin string, every variant of
    // every test would look cross-origin to its own blob URLs and workers.
    const allocator = std.testing.allocator;

    var server = WptServer{ .allocator = allocator, .wpt_root = "tests/wpt" };

    const url = try server.buildTestUrl(allocator, "url/a-element.html", .window, "?include=file");
    defer allocator.free(url);
    const origin = try server.originFor(allocator, "url/a-element.html");
    defer allocator.free(origin);
    try std.testing.expectEqualStrings(origin, originOfUrl(url).?);
}

test "isHttpsTest keys off the filename, not the directory" {
    // WPT's convention is a flag in the *filename*. A directory that happens to
    // contain the string must not drag every test under it onto TLS.
    try std.testing.expect(isHttpsTest("fetch/api/basic/keepalive.https.any.js"));
    try std.testing.expect(isHttpsTest("cookiestore/cookieStore_get_arguments.https.html"));
    try std.testing.expect(isHttpsTest("html/dom/idlharness.https.window.js"));

    try std.testing.expect(!isHttpsTest("url/url-constructor.any.js"));
    try std.testing.expect(!isHttpsTest("dom/nodes/Element-matches.html"));
    // "https" without the trailing dot is just a word in a name.
    try std.testing.expect(!isHttpsTest("fetch/api/request/request-https.html"));
    // A directory carrying the marker does not make the test itself secure.
    try std.testing.expect(!isHttpsTest("some.https.dir/plain.html"));
}

test "a .https. test is fetched over TLS on the HTTPS port" {
    // These are 371 of the 4,107 in-scope sources. Served over plain HTTP they
    // 404 or hang, so every one of them baselines as TIMEOUT for a reason that
    // has nothing to do with the engine.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const url = try server.buildTestUrl(allocator, "cookiestore/cookieStore_get_arguments.https.html", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "https://web-platform.test:8443/cookiestore/cookieStore_get_arguments.https.html",
            url,
        );
    }

    // The suffix rewrite for generated wrappers still applies under TLS.
    {
        const url = try server.buildTestUrl(allocator, "fetch/api/basic/keepalive.https.any.js", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "https://web-platform.test:8443/fetch/api/basic/keepalive.https.any.html",
            url,
        );
    }
    {
        const url = try server.buildTestUrl(allocator, "html/dom/idlharness.https.window.js", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "https://web-platform.test:8443/html/dom/idlharness.https.window.html",
            url,
        );
    }
}

test "the document origin matches the scheme and port the test was fetched from" {
    // Blob URLs and worker script fetches are same-origin checked against this
    // string. Handing a TLS test the http:// origin makes those checks fail in
    // a way that looks like a spec bug.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const origin = try server.originFor(allocator, "url/url-constructor.any.js");
        defer allocator.free(origin);
        try std.testing.expectEqualStrings("http://web-platform.test:8000", origin);
    }
    {
        const origin = try server.originFor(allocator, "fetch/api/basic/keepalive.https.any.js");
        defer allocator.free(origin);
        try std.testing.expectEqualStrings("https://web-platform.test:8443", origin);
    }
}

test "a non-default port pair is carried into both schemes" {
    // The ports are fields, not literals, so a run that had to move off 8000
    // still builds URLs that point at itself.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();
    server.port = 8001;
    server.https_port = 8444;

    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8001/dom/nodes/Element-matches.html", url);
    }
    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.https.html", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("https://web-platform.test:8444/dom/nodes/Element-matches.https.html", url);
    }
}

test "originOfUrl keeps scheme, host and port and drops everything after" {
    try std.testing.expectEqualStrings(
        "http://web-platform.test:8000",
        originOfUrl("http://web-platform.test:8000/url/a-element.html").?,
    );
    try std.testing.expectEqualStrings(
        "https://web-platform.test:8443",
        originOfUrl("https://web-platform.test:8443/fetch/api/basic/x.https.html?q=1#frag").?,
    );
}

test "originOfUrl handles an authority with no path at all" {
    try std.testing.expectEqualStrings(
        "http://web-platform.test:8000",
        originOfUrl("http://web-platform.test:8000").?,
    );
}

test "originOfUrl stops at a query or fragment that precedes any slash" {
    try std.testing.expectEqualStrings(
        "http://web-platform.test:8000",
        originOfUrl("http://web-platform.test:8000?q=1").?,
    );
}

test "originOfUrl declines anything that is not an absolute URL" {
    try std.testing.expectEqual(@as(?[]const u8, null), originOfUrl("/url/a-element.html"));
    try std.testing.expectEqual(@as(?[]const u8, null), originOfUrl("a-element.html"));
    try std.testing.expectEqual(@as(?[]const u8, null), originOfUrl(""));
}

test "the origin of a built test URL is the origin the test will report" {
    const allocator = std.testing.allocator;

    var server = WptServer{ .allocator = allocator, .wpt_root = "tests/wpt" };

    const plain = try server.buildTestUrl(allocator, "url/a-element.html", .window, "");
    defer allocator.free(plain);
    const plain_origin = try server.originFor(allocator, "url/a-element.html");
    defer allocator.free(plain_origin);
    try std.testing.expectEqualStrings(plain_origin, originOfUrl(plain).?);

    const tls = try server.buildTestUrl(allocator, "fetch/api/basic/x.https.html", .window, "");
    defer allocator.free(tls);
    const tls_origin = try server.originFor(allocator, "fetch/api/basic/x.https.html");
    defer allocator.free(tls_origin);
    try std.testing.expectEqualStrings(tls_origin, originOfUrl(tls).?);
}
