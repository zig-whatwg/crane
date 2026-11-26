//! Lane xfo1: HTML §7.7 "check a navigation response's adherence to
//! `X-Frame-Options`" — DENY, SAMEORIGIN (including nested A->B->A chains,
//! sandboxed parent vs sandboxed target), multiple/conflicting/invalid/
//! get-decode-split headers, CSP enforcing vs report-only `frame-ancestors`
//! precedence, redirect chains, and non-iframe child navigables (`<object>`,
//! `<frame>`).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const Header = struct {
    name: []const u8,
    value: []const u8,
};

const Route = struct {
    host: ?[]const u8 = null,
    path: []const u8,
    status: u16 = 200,
    content_type: []const u8 = "text/html",
    headers: []const Header = &.{},
    body: []const u8 = "",
};

const Server = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    routes: []const Route,

    fn start(allocator: std.mem.Allocator, routes: []const Route) !*Server {
        const self = try allocator.create(Server);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .listener = try LoopbackListener.open(.{}),
            .routes = routes,
        };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    fn stop(self: *Server) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    fn proxyUrl(self: *const Server, buf: []u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}", .{self.listener.port()});
    }

    fn serve(self: *Server) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(self: *Server, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        self.answer(stream) catch {};
    }

    fn answer(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            try reader.interface.fillMore();
        }
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const target = parts.next() orelse return;

        var host: []const u8 = "";
        const path = if (std.mem.indexOf(u8, target, "://")) |scheme_end| blk: {
            const after = target[scheme_end + 3 ..];
            if (std.mem.indexOfScalar(u8, after, '/')) |slash| {
                host = after[0..slash];
                break :blk after[slash..];
            } else {
                host = after;
                break :blk "/";
            }
        } else target;

        var output: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &output);
        for (self.routes) |route| {
            if (route.host) |expected_host| {
                if (!std.ascii.eqlIgnoreCase(expected_host, host)) continue;
            }
            if (!std.mem.eql(u8, route.path, path)) continue;
            return writeReply(&writer.interface, route);
        }
        try writeReply(&writer.interface, .{
            .path = "",
            .status = 404,
            .content_type = "text/plain",
            .body = "no such route",
        });
    }

    fn writeReply(writer: *std.Io.Writer, route: Route) !void {
        const reason = switch (route.status) {
            200 => "OK",
            302 => "Found",
            else => "Not Found",
        };
        try writer.print("HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n", .{
            route.status,
            reason,
            route.content_type,
            route.body.len,
        });
        for (route.headers) |h| {
            try writer.print("{s}: {s}\r\n", .{ h.name, h.value });
        }
        try writer.writeAll("\r\n");
        try writer.writeAll(route.body);
        try writer.flush();
    }
};

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| {
        std.debug.print("xfo1 test failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn waitForDone(browser: *browser_mod.Browser, ctx: *browser_mod.Context) !void {
    for (0..500) |_| {
        const done = try ctx.evaluateScriptToString("Boolean(globalThis.xfoDone)", testing.allocator);
        defer testing.allocator.free(done);
        if (std.mem.eql(u8, done, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOutWaitingForFrame;
}

const child_loaded_html =
    \\<!doctype html><html><head><title>Loaded</title>
    \\<script>window.parent.postMessage('Loaded', '*');</script>
    \\</head><body>Loaded</body></html>
;

fn runIframeScenario(routes: []const Route, start_url: []const u8, check_script: []const u8) !void {
    const server = try Server.start(testing.allocator, routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const browser = try browser_mod.Browser.init(testing.allocator, .{
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = try server.proxyUrl(&proxy_buf), .no_proxy = "" } },
    });
    defer browser.deinit();
    try browser.navigate(start_url, .window);
    const ctx = browser.current_context orelse return error.NoPage;
    try waitForDone(browser, ctx);
    try ctx.runScript(check_script);
}

// Mirrors WPT x-frame-options/support/helper.sub.js:
// - expectAllowed waits directly for both the 'Loaded' postMessage and onload
//   (zero timers, no ordering race between postMessage and onload).
// - expectBlocked fails if any message arrives and asserts contentDocument === null on onload.
// - runNestedCase waits directly for the intermediate frame's postMessage.
const single_iframe_host_html =
    \\<!doctype html><body><script>
    \\globalThis.xfoDone = false;
    \\globalThis.expectAllowed = function(url, { sandbox, expectDoc = true } = {}) {
    \\  return new Promise((resolve, reject) => {
    \\    const i = document.createElement('iframe');
    \\    if (sandbox !== undefined) i.setAttribute('sandbox', sandbox);
    \\    let gotMsg = false;
    \\    let gotLoad = false;
    \\    const finish = () => {
    \\      if (!gotMsg || !gotLoad) return;
    \\      window.removeEventListener('message', onMsg);
    \\      const hasDoc = i.contentDocument !== null;
    \\      i.remove();
    \\      if (expectDoc && !hasDoc) return reject(new Error(`expected contentDocument for ${url}`));
    \\      resolve();
    \\    };
    \\    const onMsg = e => {
    \\      if (e.source !== i.contentWindow) return;
    \\      if (e.data !== 'Loaded') return reject(new Error(`unexpected msg ${e.data} for ${url}`));
    \\      gotMsg = true;
    \\      finish();
    \\    };
    \\    window.addEventListener('message', onMsg);
    \\    i.onload = () => { gotLoad = true; finish(); };
    \\    i.src = url;
    \\    document.body.appendChild(i);
    \\  });
    \\};
    \\globalThis.expectBlocked = function(url) {
    \\  return new Promise((resolve, reject) => {
    \\    const i = document.createElement('iframe');
    \\    const onMsg = e => {
    \\      if (e.source === i.contentWindow) {
    \\        window.removeEventListener('message', onMsg);
    \\        i.remove();
    \\        reject(new Error(`blocked frame ${url} unexpectedly sent ${e.data}`));
    \\      }
    \\    };
    \\    window.addEventListener('message', onMsg);
    \\    i.onload = () => {
    \\      window.removeEventListener('message', onMsg);
    \\      const hasDoc = i.contentDocument !== null;
    \\      i.remove();
    \\      if (hasDoc) return reject(new Error(`blocked frame ${url} still exposed contentDocument`));
    \\      resolve();
    \\    };
    \\    i.src = url;
    \\    document.body.appendChild(i);
    \\  });
    \\};
    \\globalThis.runNestedCase = function(url) {
    \\  return new Promise(resolve => {
    \\    const i = document.createElement('iframe');
    \\    const onMsg = e => {
    \\      if (e.source === i.contentWindow) {
    \\        window.removeEventListener('message', onMsg);
    \\        i.remove();
    \\        resolve(e.data);
    \\      }
    \\    };
    \\    window.addEventListener('message', onMsg);
    \\    i.src = url;
    \\    document.body.appendChild(i);
    \\  });
    \\};
    \\globalThis.xfoDone = true;
    \\</script></body>
;

fn runCasesScript(routes: []const Route, runner_js: []const u8) !void {
    const server = try Server.start(testing.allocator, routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const browser = try browser_mod.Browser.init(testing.allocator, .{
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = try server.proxyUrl(&proxy_buf), .no_proxy = "" } },
    });
    defer browser.deinit();
    try browser.navigate("http://origin-a.test/host.html", .window);
    const ctx = browser.current_context orelse return error.NoPage;
    try waitForDone(browser, ctx);
    try ctx.runScript("globalThis.xfoDone = false; globalThis.xfoError = null;");
    try ctx.runScript(runner_js);
    try waitForDone(browser, ctx);
    const err_str = try ctx.evaluateScriptToString("globalThis.xfoError ? String(globalThis.xfoError) : ''", testing.allocator);
    defer testing.allocator.free(err_str);
    if (err_str.len > 0) {
        std.debug.print("xfo1 scenario failed: {s}\n", .{err_str});
        return error.XfoAssertionFailed;
    }
}

test "X-Frame-Options: DENY blocks same-origin and cross-origin framing, allows top-level" {
    const Body = struct {
        fn run() !void {
            const routes = [_]Route{
                .{ .path = "/host.html", .body = single_iframe_host_html },
                .{ .path = "/deny", .headers = &.{.{ .name = "X-Frame-Options", .value = "DENY" }}, .body = child_loaded_html },
                .{ .path = "/deny-case", .headers = &.{.{ .name = "X-Frame-Options", .value = "  denY \t" }}, .body = child_loaded_html },
                .{
                    .path = "/top-deny",
                    .headers = &.{.{ .name = "X-Frame-Options", .value = "DENY" }},
                    .body = "<!doctype html><body><script>globalThis.xfoDone = true; globalThis.topLoaded = true;</script></body>",
                },
            };
            // Top-level navigation with DENY must still load (HTML §7.7 step 1).
            try runIframeScenario(&routes, "http://origin-a.test/top-deny", "if (!globalThis.topLoaded) throw new Error('top-level DENY blocked');");

            // Framed DENY (same-origin + cross-origin + case/whitespace) must block.
            try runCasesScript(&routes,
                \\(async () => {
                \\  try {
                \\    for (const url of [
                \\      'http://origin-a.test/deny',
                \\      'http://origin-b.test/deny',
                \\      'http://origin-a.test/deny-case',
                \\      'http://origin-b.test/deny-case',
                \\    ]) {
                \\      await expectBlocked(url);
                \\    }
                \\  } catch (e) { globalThis.xfoError = e; }
                \\  globalThis.xfoDone = true;
                \\})();
            );
        }
    };
    try onFreshThread(Body.run);
}

test "X-Frame-Options: SAMEORIGIN checks every ancestor (A->A allowed, A->B and A->B->A blocked, sandbox)" {
    const Body = struct {
        fn run() !void {
            // Mirrors WPT x-frame-options/support/nested.py:
            // - For A->A->A (should load), wait directly for 'Loaded' message.
            // - For A->B->A (should block), forward 'Loaded' immediately if it
            //   ever arrives, otherwise report 'InnerBlocked' after onload + 100ms.
            const nested_expect_load =
                \\<!doctype html><body><script>
                \\window.addEventListener('message', e => {
                \\  window.parent.postMessage(e.data === 'Loaded' ? 'InnerLoaded' : 'Unexpected', '*');
                \\});
                \\const i = document.createElement('iframe');
                \\i.src = 'http://origin-a.test/sameorigin';
                \\document.body.appendChild(i);
                \\</script></body>
            ;
            const nested_expect_block =
                \\<!doctype html><body><script>
                \\let gotMessage = false;
                \\window.addEventListener('message', e => {
                \\  gotMessage = true;
                \\  window.parent.postMessage('InnerLoaded', '*');
                \\});
                \\const i = document.createElement('iframe');
                \\i.src = 'http://origin-a.test/sameorigin';
                \\i.onload = () => {
                \\  setTimeout(() => { if (!gotMessage) window.parent.postMessage('InnerBlocked', '*'); }, 100);
                \\};
                \\document.body.appendChild(i);
                \\</script></body>
            ;
            const sandboxed_parent_srcdoc_host =
                \\<!doctype html><body><script>
                \\globalThis.xfoDone = false;
                \\globalThis.sandboxResult = null;
                \\window.addEventListener('message', e => { globalThis.sandboxResult = e.data; globalThis.xfoDone = true; });
                \\const i = document.createElement('iframe');
                \\i.setAttribute('sandbox', 'allow-scripts');
                \\i.srcdoc = `<!doctype html><body><script>
                \\  let gotMessage = false;
                \\  window.addEventListener('message', e => { gotMessage = true; parent.postMessage('InnerLoaded', '*'); });
                \\  const inner = document.createElement('iframe');
                \\  inner.src = 'http://origin-a.test/sameorigin';
                \\  inner.onload = () => setTimeout(() => { if (!gotMessage) parent.postMessage('InnerBlocked', '*'); }, 100);
                \\  document.body.appendChild(inner);
                \\</scr` + `ipt></body>`;
                \\document.body.appendChild(i);
                \\</script></body>
            ;
            const routes = [_]Route{
                .{ .path = "/host.html", .body = single_iframe_host_html },
                .{ .path = "/sameorigin", .headers = &.{.{ .name = "X-Frame-Options", .value = "SAMEORIGIN" }}, .body = child_loaded_html },
                .{ .path = "/nested-load", .body = nested_expect_load },
                .{ .path = "/nested-block", .body = nested_expect_block },
                .{ .path = "/sandbox-parent.html", .body = sandboxed_parent_srcdoc_host },
            };
            try runCasesScript(&routes,
                \\(async () => {
                \\  try {
                \\    // A -> A: allowed.
                \\    await expectAllowed('http://origin-a.test/sameorigin');
                \\
                \\    // A -> B: blocked.
                \\    await expectBlocked('http://origin-b.test/sameorigin');
                \\
                \\    // A -> A -> A: allowed.
                \\    const aaa = await runNestedCase('http://origin-a.test/nested-load');
                \\    if (aaa !== 'InnerLoaded') throw new Error(`A->A->A SAMEORIGIN should load, got ${aaa}`);
                \\
                \\    // A -> B -> A: blocked because intermediate ancestor B is cross-origin!
                \\    const aba = await runNestedCase('http://origin-b.test/nested-block');
                \\    if (aba !== 'InnerBlocked') throw new Error(`A->B->A SAMEORIGIN should block, got ${aba}`);
                \\
                \\    // Sandboxed target iframe (without allow-same-origin) on same-origin URL:
                \\    // allowed per Chromium, WebKit, and Gecko (compare ancestors against response URL origin).
                \\    await expectAllowed('http://origin-a.test/sameorigin', { sandbox: 'allow-scripts', expectDoc: false });
                \\  } catch (e) { globalThis.xfoError = e; }
                \\  globalThis.xfoDone = true;
                \\})();
            );

            // Sandboxed parent (opaque ancestor origin) -> same-origin URL with SAMEORIGIN: blocked.
            try runIframeScenario(
                &routes,
                "http://origin-a.test/sandbox-parent.html",
                "if (globalThis.sandboxResult !== 'InnerBlocked') throw new Error('sandboxed opaque parent should block SAMEORIGIN, got ' + globalThis.sandboxResult);",
            );
        }
    };
    try onFreshThread(Body.run);
}

test "X-Frame-Options: multiple, conflicting, invalid, and get-decode-split headers" {
    const Body = struct {
        fn run() !void {
            const routes = [_]Route{
                .{ .path = "/host.html", .body = single_iframe_host_html },
                .{
                    .path = "/dup-sameorigin",
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "SAMEORIGIN" },
                        .{ .name = "X-Frame-Options", .value = "sameOrigin" },
                    },
                    .body = child_loaded_html,
                },
                .{
                    .path = "/conflict-so-deny",
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "SAMEORIGIN" },
                        .{ .name = "X-Frame-Options", .value = "DENY" },
                    },
                    .body = child_loaded_html,
                },
                .{
                    .path = "/conflict-so-invalid",
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "SAMEORIGIN" },
                        .{ .name = "X-Frame-Options", .value = "INVALID" },
                    },
                    .body = child_loaded_html,
                },
                .{
                    .path = "/conflict-so-empty",
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "SAMEORIGIN" },
                        .{ .name = "X-Frame-Options", .value = "" },
                    },
                    .body = child_loaded_html,
                },
                .{
                    .path = "/conflict-allowall-invalid",
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "ALLOWALL, INVALID" },
                    },
                    .body = child_loaded_html,
                },
                .{ .path = "/invalid-only", .headers = &.{.{ .name = "X-Frame-Options", .value = "INVALID, FOO" }}, .body = child_loaded_html },
                .{ .path = "/allowall", .headers = &.{.{ .name = "X-Frame-Options", .value = "ALLOWALL" }}, .body = child_loaded_html },
                .{ .path = "/allow-from", .headers = &.{.{ .name = "X-Frame-Options", .value = "ALLOW-FROM https://example.com/" }}, .body = child_loaded_html },
                .{ .path = "/quoted-deny", .headers = &.{.{ .name = "X-Frame-Options", .value = "\"SAMEORIGIN,DENY\"" }}, .body = child_loaded_html },
                .{ .path = "/vt-deny", .headers = &.{.{ .name = "X-Frame-Options", .value = "\x0bDENY" }}, .body = child_loaded_html },
                .{ .path = "/ff-deny", .headers = &.{.{ .name = "X-Frame-Options", .value = "\x0cDENY" }}, .body = child_loaded_html },
            };
            try runCasesScript(&routes,
                \\(async () => {
                \\  try {
                \\    // Duplicate SAMEORIGIN: allowed same-origin, blocked cross-origin.
                \\    await expectAllowed('http://origin-a.test/dup-sameorigin');
                \\    await expectBlocked('http://origin-b.test/dup-sameorigin');
                \\
                \\    // Conflicting values containing deny/sameorigin/allowall: blocked even same-origin.
                \\    for (const path of ['/conflict-so-deny', '/conflict-so-invalid', '/conflict-so-empty', '/conflict-allowall-invalid']) {
                \\      await expectBlocked('http://origin-a.test' + path);
                \\    }
                \\
                \\    // Invalid / legacy / quoted / non-HTTP-whitespace values: allowed even cross-origin.
                \\    for (const path of ['/invalid-only', '/allowall', '/allow-from', '/quoted-deny', '/vt-deny', '/ff-deny']) {
                \\      await expectAllowed('http://origin-b.test' + path, { expectDoc: false });
                \\    }
                \\  } catch (e) { globalThis.xfoError = e; }
                \\  globalThis.xfoDone = true;
                \\})();
            );
        }
    };
    try onFreshThread(Body.run);
}

test "X-Frame-Options: enforcing CSP frame-ancestors overrides XFO, report-only and non-FA CSP do not" {
    const Body = struct {
        fn run() !void {
            const routes = [_]Route{
                .{ .path = "/host.html", .body = single_iframe_host_html },
                .{
                    .path = "/csp-fa-overrides-deny",
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "DENY" },
                        .{ .name = "Content-Security-Policy", .value = "frame-ancestors 'self'" },
                    },
                    .body = child_loaded_html,
                },
                .{
                    .path = "/csp-default-no-override",
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "DENY" },
                        .{ .name = "Content-Security-Policy", .value = "default-src 'self'" },
                    },
                    .body = child_loaded_html,
                },
                .{
                    .path = "/csp-ro-no-override",
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "DENY" },
                        .{ .name = "Content-Security-Policy-Report-Only", .value = "frame-ancestors 'self'" },
                    },
                    .body = child_loaded_html,
                },
            };
            try runCasesScript(&routes,
                \\(async () => {
                \\  try {
                \\    await expectAllowed('http://origin-a.test/csp-fa-overrides-deny');
                \\    await expectBlocked('http://origin-b.test/csp-fa-overrides-deny');
                \\    await expectBlocked('http://origin-a.test/csp-default-no-override');
                \\    await expectBlocked('http://origin-a.test/csp-ro-no-override');
                \\  } catch (e) { globalThis.xfoError = e; }
                \\  globalThis.xfoDone = true;
                \\})();
            );
        }
    };
    try onFreshThread(Body.run);
}

test "X-Frame-Options: redirect responses ignored, final response checked against final origin" {
    const Body = struct {
        fn run() !void {
            const routes = [_]Route{
                .{ .path = "/host.html", .body = single_iframe_host_html },
                .{
                    .path = "/redir-deny-to-allow",
                    .status = 302,
                    .headers = &.{
                        .{ .name = "X-Frame-Options", .value = "DENY" },
                        .{ .name = "Location", .value = "http://origin-a.test/final-allow" },
                    },
                },
                .{
                    .path = "/final-allow",
                    .headers = &.{.{ .name = "X-Frame-Options", .value = "ALLOWALL" }},
                    .body = child_loaded_html,
                },
                .{
                    .path = "/redir-to-cross-sameorigin",
                    .status = 302,
                    .headers = &.{
                        .{ .name = "Location", .value = "http://origin-b.test/final-sameorigin" },
                    },
                },
                .{
                    .path = "/redir-to-same-sameorigin",
                    .status = 302,
                    .headers = &.{
                        .{ .name = "Location", .value = "http://origin-a.test/final-sameorigin" },
                    },
                },
                .{
                    .path = "/final-sameorigin",
                    .headers = &.{.{ .name = "X-Frame-Options", .value = "SAMEORIGIN" }},
                    .body = child_loaded_html,
                },
            };
            try runCasesScript(&routes,
                \\(async () => {
                \\  try {
                \\    await expectAllowed('http://origin-a.test/redir-deny-to-allow');
                \\    await expectBlocked('http://origin-a.test/redir-to-cross-sameorigin');
                \\    await expectAllowed('http://origin-b.test/redir-to-same-sameorigin');
                \\  } catch (e) { globalThis.xfoError = e; }
                \\  globalThis.xfoDone = true;
                \\})();
            );
        }
    };
    try onFreshThread(Body.run);
}

test "X-Frame-Options: DENY blocks object and frame child navigables" {
    const Body = struct {
        fn run() !void {
            const obj_host =
                \\<!doctype html><body><script>
                \\globalThis.xfoDone = false;
                \\globalThis.objMsg = null;
                \\window.addEventListener('message', e => { globalThis.objMsg = e.data; });
                \\const obj = document.createElement('object');
                \\obj.type = 'text/html';
                \\obj.data = 'http://origin-a.test/deny';
                \\obj.onload = () => { globalThis.objHasDoc = obj.contentDocument !== null; globalThis.xfoDone = true; };
                \\document.body.appendChild(obj);
                \\</script></body>
            ;
            const frameset_host =
                \\<!doctype html><html><head><script>
                \\globalThis.xfoDone = false;
                \\globalThis.frameMsg = null;
                \\window.addEventListener('message', e => { globalThis.frameMsg = e.data; });
                \\window.onload = () => {
                \\  const f = document.getElementById('f');
                \\  globalThis.frameHasDoc = f.contentDocument !== null;
                \\  globalThis.xfoDone = true;
                \\};
                \\</script></head><frameset><frame id="f" src="http://origin-a.test/deny"></frameset></html>
            ;
            const routes = [_]Route{
                .{ .path = "/obj.html", .body = obj_host },
                .{ .path = "/frameset.html", .body = frameset_host },
                .{ .path = "/deny", .headers = &.{.{ .name = "X-Frame-Options", .value = "DENY" }}, .body = child_loaded_html },
            };
            try runIframeScenario(
                &routes,
                "http://origin-a.test/obj.html",
                "if (globalThis.objMsg !== null || globalThis.objHasDoc) throw new Error('object with XFO DENY should block');",
            );
            try runIframeScenario(
                &routes,
                "http://origin-a.test/frameset.html",
                "if (globalThis.frameMsg !== null || globalThis.frameHasDoc) throw new Error('frame with XFO DENY should block');",
            );
        }
    };
    try onFreshThread(Body.run);
}
